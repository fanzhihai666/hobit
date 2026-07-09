package com.habit.vo;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

import java.util.List;

@Data
public class CardDataVO {
    @JsonProperty("isLoggedIn")
    private boolean loggedIn;
    private int completedCount;
    private int totalCount;
    private int progress;
    private List<CardHabitItemVO> habits;
    private boolean showToast;
    private String toastMessage;
}
