package com.habit.vo;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

@Data
public class CardHabitItemVO {
    private Long id;
    private String name;
    private String icon;
    @JsonProperty("isCheckedIn")
    private boolean checkedIn;
    @JsonProperty("isDaily")
    private boolean daily;
}
