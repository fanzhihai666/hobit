package com.habit.controller;

import com.habit.common.Result;
import com.habit.entity.User;
import com.habit.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/user")
public class UserController {

    @Autowired
    private UserService userService;

    @PostMapping("/register")
    public Result<Boolean> register(@RequestBody User user) {
        if (user.getUsername() == null || user.getUsername().trim().isEmpty()) {
            return Result.error("用户名不能为空");
        }
        if (user.getPassword() == null || user.getPassword().trim().isEmpty()) {
            return Result.error("密码不能为空");
        }
        if (userService.getByUsername(user.getUsername()) != null) {
            return Result.error("用户名已存在");
        }
        // 后端 MD5 加密（APP 传明文）
        user.setPassword(userService.md5Encrypt(user.getPassword()));
        boolean save = userService.save(user);
        return Result.success(save);
    }

    @PostMapping("/login")
    public Result<Map<String, Object>> login(@RequestBody User loginUser) {
        if (loginUser.getUsername() == null || loginUser.getPassword() == null) {
            return Result.error("用户名或密码不能为空");
        }
        User user = userService.getByUsername(loginUser.getUsername());
        if (user == null) {
            return Result.error("用户不存在");
        }
        String encryptedPassword = userService.md5Encrypt(loginUser.getPassword());
        if (!user.getPassword().equals(encryptedPassword)) {
            return Result.error("密码错误");
        }

        String token = userService.generateToken(user);
        Map<String, Object> result = new HashMap<>();
        result.put("token", token);
        // 不返回密码
        user.setPassword(null);
        result.put("user", user);
        return Result.success(result);
    }
}
