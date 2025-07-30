# 洛盘生产管理系统 (Lopan Production Management System)

一个基于 SwiftUI 和 SwiftData 的企业级生产管理系统，支持多角色用户管理和生产流程控制。

## 功能特性

### 🔐 用户认证与角色管理
- **微信登录**: 支持微信ID登录系统
- **角色分配**: 管理员可以为用户分配不同角色
- **权限控制**: 基于角色的功能访问控制

### 👥 用户角色

#### 1. 销售员 (Salesperson)
- 客户订单数据查询、添加、删除和修改
- 销售数据分析

#### 2. 仓库管理员 (Warehouse Keeper)
- 日常生产款式控制
- 入库状态管理

#### 3. 车间经理 (Workshop Manager)
- 根据车间不同机器当日生产状态填写款式、产量、颜色等
- 设备状态监控

#### 4. EVA造粒技术员 (EVA Granulation Technician)
- 填写每日消耗的原材料
- 记录生产的颜色和产量

#### 5. 车间技术员 (Workshop Technician)
- 填写负责的机器
- 报告日常生产过程中的问题

#### 6. 管理员 (Administrator)
- 用户管理和角色分配
- 系统概览和所有功能页面访问
- 生产状态协调

### 📱 界面特性
- **现代化UI**: 采用 SwiftUI 构建的现代化界面
- **响应式设计**: 适配不同屏幕尺寸
- **角色化界面**: 根据用户角色显示不同功能模块
- **实时数据**: 使用 SwiftData 进行本地数据管理

## 技术架构

### 核心技术
- **SwiftUI**: 用户界面框架
- **SwiftData**: 数据持久化
- **Combine**: 响应式编程

### 数据模型
- `User`: 用户信息和角色管理
- `CustomerOrder`: 客户订单管理
- `ProductionStyle`: 生产款式管理
- `WorkshopProduction`: 车间生产管理
- `EVAGranulation`: EVA造粒记录
- `WorkshopIssue`: 车间问题报告

## 使用说明

### 首次使用
1. 启动应用后，使用"演示登录"功能
2. 选择不同角色体验不同功能
3. 管理员角色可以管理用户和分配角色

### 角色体验
- **销售员**: 体验客户订单管理功能
- **仓库管理员**: 体验生产款式和入库管理
- **车间经理**: 体验生产状态管理
- **EVA造粒技术员**: 体验造粒记录功能
- **车间技术员**: 体验问题报告功能
- **管理员**: 体验用户管理和系统概览

## 开发状态

### ✅ 已完成
- 用户认证系统
- 角色管理框架
- 销售员订单管理功能
- 管理员用户管理功能
- 基础UI框架

### 🚧 开发中
- 仓库管理功能
- 车间生产管理
- EVA造粒记录
- 问题报告系统
- 数据分析功能

## 系统要求
- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## 安装和运行

1. 克隆项目到本地
2. 使用 Xcode 打开 `Lopan.xcodeproj`
3. 选择目标设备或模拟器
4. 点击运行按钮

## 项目结构

```
Lopan/
├── Models/                 # 数据模型
│   ├── User.swift
│   ├── CustomerOrder.swift
│   ├── ProductionStyle.swift
│   ├── WorkshopProduction.swift
│   ├── EVAGranulation.swift
│   └── WorkshopIssue.swift
├── Services/               # 服务层
│   └── AuthenticationService.swift
├── Views/                  # 视图层
│   ├── LoginView.swift
│   ├── DashboardView.swift
│   ├── Salesperson/        # 销售员功能
│   ├── Administrator/      # 管理员功能
│   └── PlaceholderViews.swift
└── LopanApp.swift         # 应用入口
```

## 贡献指南

欢迎提交 Issue 和 Pull Request 来改进这个项目。

## 许可证

© 2025 洛盘科技有限公司 