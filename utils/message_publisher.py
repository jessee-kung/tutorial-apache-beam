from abc import abstractmethod
from typing import List, Dict
from datetime import datetime
from concurrent import futures
from datetime import datetime
import time

import uuid
import json

import logging
from logging import getLogger

from google.cloud.pubsublite.cloudpubsub import PublisherClient
from google.cloud.pubsublite.types import (
    CloudRegion,
    CloudZone,
    TopicPath,
    MessageMetadata,
)


class PubSubLitePublisher:
    def __init__(self, topic_id: str):
        assert isinstance(topic_id, str), "'topic_id' must be 'str'"
        
        tokens = topic_id.split("/")
        assert len(tokens) == 6 and tokens[0] == "projects" and tokens[2] == "locations" and tokens[4] == "topics", "unexpected 'topic_id' format, expected to be: '/projects/<project_number>/locations/<zone>/topics/<topic_name>'"

        project, location, topic = tokens[1], tokens[3], tokens[5]

        region, zone = location.rsplit("-", 1)

        self._location = CloudZone(CloudRegion(region), zone)
        self._topic_path = TopicPath(project, self._location, topic)
        self._client = PublisherClient()

    @staticmethod
    def _sent_callback(api_future: futures.Future):
        message_id = api_future.result()
        message_metadata = MessageMetadata.decode(message_id)
        getLogger().debug(
            "message published: partition={}, offset={}".format(
                message_metadata.partition.value,
                message_metadata.cursor.offset,
            )
        )

    def send_messages(self, messages: List["PubSubLiteMessage"], dry_run: bool = False):
        def send_message(message: PubSubLiteMessage):
            attr_map = {"x-goog-pubsublite-dataflow-uuid": str(uuid.uuid4())}
            api_future = self._client.publish(
                self._topic_path,
                message.encode().encode("utf-8"),
                **attr_map,
            )
            api_future.add_done_callback(PubSubLitePublisher._sent_callback)
            published_futures.append(api_future)

        def send_message_dryrun(message: PubSubLiteMessage):
            getLogger().info(message.encode().encode("utf-8"))

        published_futures = []
        for message in messages:
            if dry_run:
                send_message_dryrun(message)
            else:
                send_message(message)
        if not dry_run:
            futures.wait(published_futures, return_when=futures.ALL_COMPLETED)
        getLogger().info("enque {} messages".format(len(messages)))

    def __enter__(self):
        self._client.__enter__()
        getLogger().info("publisher client created, topic_path={}".format(self._topic_path))
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self._client.__exit__(exc_type, exc_value, traceback)


class PubSubLiteMessage:
    def __init__(self):
        pass

    @abstractmethod
    def encode(self) -> str:
        raise NotImplementedError("method 'encode' is not implemented")
    

class BeamTutorialMessage(PubSubLiteMessage):
    def __init__(self, event_time: int, user_id: int, click: int):
        super().__init__()
        self.event_time = event_time
        self.user_id = user_id
        self.click = click

    def encode(self) -> str:
        m = {
            "event_time": self.event_time,
            "user_id": self.user_id,
            "click": self.click,
        }
        return json.dumps(m)


if __name__ == "__main__":
    logging.basicConfig(format="%(asctime)s [%(levelname)s] %(message)s", level=logging.INFO)

    topic_id = "" # Replace with your Pub/Sub Lite Topic ID
    with PubSubLitePublisher(topic_id) as publisher:
        messages = []
        for user_id in range(1000, 1003):
            n = 10
            ts = int(time.mktime(datetime.now().timetuple()))
            messages = [BeamTutorialMessage(ts - (n-i-1)*10, user_id, 1) for i in range(n)]

            getLogger().info("generate {} messages for user_id = {}".format(n, user_id))
            publisher.send_messages(messages)
