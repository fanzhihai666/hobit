package com.habit.common;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AppConfig {

    @Value("${server.port:8080}")
    private int serverPort;

    @Value("${image.access-path}")
    private String imageAccessPath;

    private static String baseUrl;

    @Bean
    public String imageBaseUrl() {
        String ip = IpUtil.getLocalIp();
        baseUrl = "http://" + ip + ":" + serverPort + imageAccessPath;
        System.out.println("========================================");
        System.out.println("图片访问基础 URL: " + baseUrl);
        System.out.println("========================================");
        return baseUrl;
    }

    public static String getBaseUrl() {
        return baseUrl;
    }
}
