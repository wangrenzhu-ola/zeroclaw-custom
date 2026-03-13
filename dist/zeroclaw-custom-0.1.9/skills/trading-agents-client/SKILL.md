---
name: "trading-agents-client"
description: "一个用于与 TradingAgents-CN API 交互的私有技能。支持股票分析、模拟交易、高级数据查询和系统管理。当用户询问股票分析、市场数据、财务报告或交易模拟时调用。"
---

# TradingAgents Client (Private)

此技能为托管在 `114.66.57.22` 的 TradingAgents-CN 系统提供编程接口。用于全面的股票研究、技术分析、实时市场监控和模拟交易。

## 核心能力

- **股票分析**: 提交多智能体分析任务，支持自定义深度和分析师组合。
- **任务追踪**: 实时监控分析任务的进度和状态。
- **研报获取**: 获取最终的研究报告，包括摘要、投资建议和详细分析。
- **市场数据**: 查询实时行情、财务数据和个股新闻。
- **模拟交易**: 管理虚拟交易账户，下单并查看持仓。
- **系统管理**: 检查系统健康状态和查看操作日志。

## 配置信息

此技能直接连接到远程 API，无需本地隧道。
- **API Base URL**: `http://114.66.57.22:8000/api`
- **认证方式**: 需要 Bearer Token。
- **默认模型**: `MiniMax-M2.5-highspeed`

## 常用工作流与参数 Schema

### 1. 执行股票分析
CLI 命令: `client.py analyze [symbol] --depth [depth] --wait`

**Schema (Analysis Request):**
```json
{
  "symbol": "string (Required) - 6位数字股票代码，如 '000001'",
  "depth": "string (Optional) - 分析深度: '快速'(默认), '基础', '标准', '深度', '全面'",
  "market": "string (Optional) - 市场类型: 'A股'(默认), '港股', '美股'",
  "analysts": ["string"] (Optional) - 启用的分析师: ['market', 'fundamentals', 'news', 'social_media']
}
```

- **分析深度说明**:
  - `快速`: 2-5分钟，基础数据概览，快速决策
  - `基础`: 3-6分钟，常规投资决策
  - `标准`: 4-8分钟，技术+基本面，推荐
  - `深度`: 6-11分钟，多轮辩论，深度研究
  - `全面`: 8-16分钟，最全面的分析报告

- **分析师团队说明**:
  - `market`: 市场分析师 - 分析市场趋势、行业动态和宏观经济环境
  - `fundamentals`: 基本面分析师 - 分析公司财务状况、业务模式和竞争优势
  - `news`: 新闻分析师 - 分析相关新闻、公告和市场事件的影响
  - `social_media`: 社媒分析师 - 分析社交媒体情绪、投资者心理和舆论导向

### 2. 获取实时价格
CLI 命令: `client.py quote [symbol]`

**Schema (Quote Response):**
```json
{
  "symbol": "string - 股票代码",
  "price": "float - 当前价格",
  "change": "float - 涨跌额",
  "pct_chg": "float - 涨跌幅(%)",
  "volume": "float - 成交量"
}
```

### 3. 模拟交易
CLI 命令: `client.py paper-order [symbol] [action] [quantity] --price [price]`

**Schema (Order Request):**
```json
{
  "symbol": "string (Required) - 股票代码",
  "action": "string (Required) - 'buy' 或 'sell'",
  "quantity": "integer (Required) - 交易数量 (手/股)",
  "price": "float (Optional) - 限价单价格，不填则为市价单"
}
```

### 4. 高级数据
CLI 命令: `client.py financials [symbol]` / `client.py news [symbol]`

**Schema (News Response):**
```json
{
  "title": "string - 新闻标题",
  "content": "string - 新闻内容",
  "pub_time": "string - 发布时间",
  "source": "string - 来源"
}
```

### 5. 系统管理
CLI 命令: `client.py system-status` / `client.py logs`

**Schema (System Status Response):**
```json
{
  "database": {
    "mongodb": {"connected": true, "connections": 10},
    "redis": {"connected": true, "memory_used": 1024}
  },
  "queue": {"active": 0, "pending": 0}
}
```

## 使用指南

- **代码验证**: 提交分析前请务必验证股票代码（A股为6位数字）。
- **错误处理**: 该客户端已处理 SSL 证书验证问题（忽略自签名证书错误）。
- **频率限制**: 请遵守速率限制，避免过于频繁地轮询任务状态。
