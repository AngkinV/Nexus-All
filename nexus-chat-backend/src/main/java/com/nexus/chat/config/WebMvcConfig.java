package com.nexus.chat.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Web MVC 配置
 * 配置静态资源访问路径
 */
@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    /**
     * 配置静态资源处理器
     * 使 /uploads/** 路径可以访问 uploads/ 目录下的文件
     */
    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // 配置上传文件的静态资源访问
        // 访问 /uploads/** 会映射到项目根目录的 uploads/ 文件夹
        registry.addResourceHandler("/uploads/**")
                .addResourceLocations("file:uploads/")
                .setCachePeriod(3600); // 缓存1小时

        // 配置 APK 下载的静态资源访问
        // 访问 /apk/** 会映射到 apk/ 目录下的文件
        registry.addResourceHandler("/apk/**")
                .addResourceLocations("file:apk/")
                .setCachePeriod(86400); // 缓存24小时
    }
}
