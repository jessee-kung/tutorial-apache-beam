package com.jesseekung.beamtutorial.entity;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.google.api.services.bigquery.model.TableRow;
import org.joda.time.Instant;

public class InputMessage {
  private Long eventTime;
  private Integer userId;
  private Integer click;

  @JsonProperty("event_time")
  public Long getEventTime() {
    return this.eventTime;
  }

  public void setEventTime(Long eventTime) {
    this.eventTime = eventTime;
  }

  @JsonProperty("user_id")
  public Integer getUserId() {
    return this.userId;
  }

  public void setUserId(Integer userId) {
    this.userId = userId;
  }

  @JsonProperty("click")
  public Integer getClick() {
    return this.click;
  }

  public void setClick(Integer click) {
    this.click = click;
  }

  public TableRow toTableRow() {
    TableRow row = new TableRow();

    row.put("event_time", eventTime);
    row.put("processing_time", Instant.now().getMillis() / 1000);
    row.put("user_id", userId);
    row.put("click", click);

    return row;
  }
}
