#!/usr/bin/env python3
"""
TradingAgents Client CLI
封装远程 API，方便 Agent 调用。
"""

import os
import sys
import json
import time
import argparse
import requests
import urllib3
from typing import Optional, Dict, Any, List

# 禁用自签名证书的 SSL 警告
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# 默认配置
DEFAULT_BASE_URL = "http://114.66.57.22:8000/api"
DEFAULT_TOKEN = os.environ.get("TRADING_AGENTS_TOKEN", "")

class TradingAgentsClient:
    def __init__(self, base_url: str = DEFAULT_BASE_URL, token: str = DEFAULT_TOKEN):
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.headers = {"Content-Type": "application/json"}
        
        # 优先使用传入的Token
        if self.token:
            if len(self.token) > 100: # JWT
                self.headers["Authorization"] = f"Bearer {self.token}"
            else: # API Key
                self.headers["X-CN-API-TOKEN"] = f"{self.token}"
        else:
            # 没有Token时，尝试自动登录
            self._auto_login()

    def _auto_login(self):
        """使用内置账号自动登录获取Token"""
        login_url = f"{self.base_url}/auth/login"
        try:
            # 内置默认账号
            payload = {
                "username": "admin",
                "password": "admin123"
            }
            # print(f"🔄 正在尝试自动登录 ({payload['username']})...")
            response = requests.post(login_url, json=payload, verify=False, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            if data.get("success"):
                token_data = data.get("data", {})
                self.token = token_data.get("access_token")
                if self.token:
                    self.headers["Authorization"] = f"Bearer {self.token}"
                    # print(f"✅ 登录成功！已自动获取 Token。")
                else:
                    print("❌ 登录响应中未找到Token")
            else:
                print(f"❌ 登录失败: {data.get('message')}")
                
        except Exception as e:
            print(f"❌ 自动登录异常: {e}")
            # print("⚠️ 将尝试使用无Token模式继续（可能会失败）")

    def _request(self, method: str, endpoint: str, **kwargs) -> Dict[str, Any]:
        """向 API 发送 HTTP 请求"""
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        
        # 内部重试函数
        def do_request():
            response = requests.request(
                method, 
                url, 
                headers=self.headers, 
                verify=False, 
                **kwargs
            )
            response.raise_for_status()
            return response.json()

        try:
            return do_request()
        except requests.exceptions.HTTPError as e:
            # 如果遇到 401 且之前没有强制登录过，尝试重新登录并重试一次
            if e.response.status_code == 401:
                print("⚠️ Token已过期或无效，尝试重新登录...")
                self._auto_login()
                try:
                    return do_request()
                except requests.exceptions.HTTPError as e2:
                    # 重试依然失败，则抛出异常
                    self._handle_http_error(e2, endpoint)
            else:
                self._handle_http_error(e, endpoint)
        except Exception as e:
            print(f"请求发生异常: {e}")
            sys.exit(1)

    def _handle_http_error(self, e, endpoint):
        print(f"调用接口失败 {endpoint}: {e}")
        if e.response.content:
            try:
                print(f"服务器响应: {json.dumps(e.response.json(), indent=2, ensure_ascii=False)}")
            except:
                print(f"服务器响应: {e.response.text}")
        sys.exit(1)

    def search_stock(self, keyword: str) -> List[Dict[str, Any]]:
        """根据关键字搜索股票"""
        params = {"keyword": keyword}
        data = self._request("GET", "stock-data/search", params=params)
        return data.get("data", [])

    def get_quote(self, symbol: str) -> Dict[str, Any]:
        """获取股票实时行情"""
        data = self._request("GET", f"stock-data/quotes/{symbol}")
        return data.get("data", {})

    def submit_analysis(self, symbol: str, depth: str = "快速", 
                       market: str = "A股", analysts: List[str] = None) -> str:
        """提交单股分析任务"""
        if analysts is None:
            analysts = ["market", "fundamentals"]
            
        payload = {
            "stock_code": symbol,
            "parameters": {
                "research_depth": depth,
                "market_type": market,
                "selected_analysts": analysts,
                "quick_analysis_model": "MiniMax-M2.5-highspeed",
                "deep_analysis_model": "MiniMax-M2.5-highspeed"
            }
        }
        
        data = self._request("POST", "analysis/single", json=payload)
        return data.get("data", {}).get("task_id")

    def get_task_status(self, task_id: str) -> Dict[str, Any]:
        """获取分析任务状态"""
        data = self._request("GET", f"analysis/tasks/{task_id}/status")
        return data.get("data", {})

    def get_task_result(self, task_id: str) -> Dict[str, Any]:
        """获取已完成分析任务的结果"""
        data = self._request("GET", f"analysis/tasks/{task_id}/result")
        return data.get("data", {})

    def list_reports(self, limit: int = 10) -> List[Dict[str, Any]]:
        """获取最近的分析报告列表"""
        params = {"limit": limit}
        data = self._request("GET", "reports/list", params=params)
        return data.get("data", {}).get("reports", [])

    def wait_for_task(self, task_id: str, timeout: int = 300) -> Dict[str, Any]:
        """轮询任务状态直到完成或超时"""
        start_time = time.time()
        print(f"正在等待任务 {task_id} 完成...")
        
        while time.time() - start_time < timeout:
            status_data = self.get_task_status(task_id)
            status = status_data.get("status")
            progress = status_data.get("progress", 0)
            step = status_data.get("current_step_name", "初始化中")
            
            print(f"状态: {status} ({progress}%) - {step}")
            
            if status == "completed":
                print("任务成功完成！")
                return self.get_task_result(task_id)
            elif status == "failed":
                print(f"任务失败: {status_data.get('error_message')}")
                return None
            
            time.sleep(5)
            
        print("等待任务超时。")
        return None

    # ===== 模拟交易能力 =====
    def get_paper_account(self) -> Dict[str, Any]:
        """获取模拟交易账户信息"""
        data = self._request("GET", "paper/account")
        return data.get("data", {})

    def place_paper_order(self, symbol: str, action: str, quantity: int, price: float = None) -> Dict[str, Any]:
        """下模拟交易单"""
        # 注意：此处参数需与后端模型对齐
        payload = {
            "symbol": symbol,
            "code": symbol, # 兼容后端字段
            "action": action.lower(),  # buy/sell
            "side": action.lower(), # 兼容后端字段
            "quantity": quantity,
            "price": price,
            "order_type": "limit" if price else "market"
        }
        data = self._request("POST", "paper/order", json=payload)
        return data.get("data", {})

    def list_paper_positions(self) -> List[Dict[str, Any]]:
        """列出模拟交易持仓"""
        data = self._request("GET", "paper/positions")
        return data.get("data", [])

    # ===== 高级数据能力 =====
    def get_financial_data(self, symbol: str) -> Dict[str, Any]:
        """获取个股最新财务数据"""
        data = self._request("GET", f"financial-data/latest/{symbol}")
        return data.get("data", {})

    def get_news_data(self, symbol: str, limit: int = 5) -> List[Dict[str, Any]]:
        """获取个股新闻"""
        params = {"limit": limit}
        data = self._request("GET", f"news-data/query/{symbol}", params=params)
        return data.get("data", [])

    # ===== 系统管理能力 =====
    def get_system_status(self) -> Dict[str, Any]:
        """获取系统健康状态"""
        db_status = self._request("GET", "system/database/status").get("data", {})
        queue_stats = self._request("GET", "queue/stats").get("data", {})
        return {
            "database": db_status,
            "queue": queue_stats
        }

    def list_logs(self, limit: int = 20) -> List[Dict[str, Any]]:
        """查看系统操作日志"""
        params = {"limit": limit}
        data = self._request("GET", "system/logs/list", params=params)
        return data.get("data", {}).get("items", [])

def main():
    parser = argparse.ArgumentParser(description="TradingAgents 客户端 CLI")
    subparsers = parser.add_subparsers(dest="command", help="执行指令")
    
    # search
    search_parser = subparsers.add_parser("search", help="搜索股票")
    search_parser.add_argument("keyword", help="股票代码或名称关键字")
    
    # quote
    quote_parser = subparsers.add_parser("quote", help="获取实时行情")
    quote_parser.add_argument("symbol", help="股票代码 (如 000001)")
    
    # analyze
    analyze_parser = subparsers.add_parser("analyze", help="执行股票分析")
    analyze_parser.add_argument("symbol", help="股票代码 (如 000001)")
    analyze_parser.add_argument("--depth", default="快速", help="分析深度 (快速/基础/标准/深度/综合/1-5)")
    analyze_parser.add_argument("--wait", action="store_true", help="等待任务完成并显示结果")
    
    # reports
    reports_parser = subparsers.add_parser("reports", help="列出最近研报")
    reports_parser.add_argument("--limit", type=int, default=10, help="显示报告数量")

    # status
    status_parser = subparsers.add_parser("status", help="查询任务状态")
    status_parser.add_argument("task_id", help="任务ID")
    
    # paper trading
    subparsers.add_parser("paper-account", help="获取模拟账户资产")
    
    paper_order_parser = subparsers.add_parser("paper-order", help="模拟交易下单")
    paper_order_parser.add_argument("symbol", help="股票代码")
    paper_order_parser.add_argument("action", choices=["buy", "sell"], help="买入或卖出")
    paper_order_parser.add_argument("quantity", type=int, help="数量")
    paper_order_parser.add_argument("--price", type=float, help="限价价格 (不填则为市价)")
    
    subparsers.add_parser("paper-positions", help="查看模拟持仓")
    
    # advanced data
    financial_parser = subparsers.add_parser("financials", help="查看财务数据")
    financial_parser.add_argument("symbol", help="股票代码")
    
    news_parser = subparsers.add_parser("news", help="查看个股新闻")
    news_parser.add_argument("symbol", help="股票代码")
    news_parser.add_argument("--limit", type=int, default=5, help="新闻条数")
    
    # system
    subparsers.add_parser("system-status", help="系统健康状态")
    
    logs_parser = subparsers.add_parser("logs", help="查看操作日志")
    logs_parser.add_argument("--limit", type=int, default=20, help="日志条数")

    args = parser.parse_args()
    
    # 鉴权 Token (可选，如果不提供则自动登录)
    token = os.environ.get("TRADING_AGENTS_TOKEN")
    
    client = TradingAgentsClient(token=token)
    
    if args.command == "search":
        results = client.search_stock(args.keyword)
        print(json.dumps(results, indent=2, ensure_ascii=False))
        
    elif args.command == "quote":
        quote = client.get_quote(args.symbol)
        print(json.dumps(quote, indent=2, ensure_ascii=False))
        
    elif args.command == "analyze":
        task_id = client.submit_analysis(args.symbol, depth=args.depth)
        print(f"任务已提交。ID: {task_id}")
        
        if args.wait:
            result = client.wait_for_task(task_id)
            if result:
                print("\n=== 分析摘要 ===")
                print(result.get("summary", "暂无摘要。"))
                print("\n=== 投资建议 ===")
                print(result.get("recommendation", "暂无建议。"))
                
    elif args.command == "reports":
        reports = client.list_reports(limit=args.limit)
        print(json.dumps(reports, indent=2, ensure_ascii=False))

    elif args.command == "status":
        status = client.get_task_status(args.task_id)
        print(json.dumps(status, indent=2, ensure_ascii=False))
        if status.get("status") == "completed":
            result = client.get_task_result(args.task_id)
            print("\n=== 分析摘要 ===")
            print(result.get("summary", "暂无摘要。"))
            print("\n=== 投资建议 ===")
            print(result.get("recommendation", "暂无建议。"))
        
    elif args.command == "paper-account":
        account = client.get_paper_account()
        print(json.dumps(account, indent=2, ensure_ascii=False))
        
    elif args.command == "paper-order":
        order = client.place_paper_order(args.symbol, args.action, args.quantity, args.price)
        print(json.dumps(order, indent=2, ensure_ascii=False))
        
    elif args.command == "paper-positions":
        positions = client.list_paper_positions()
        print(json.dumps(positions, indent=2, ensure_ascii=False))
        
    elif args.command == "financials":
        data = client.get_financial_data(args.symbol)
        print(json.dumps(data, indent=2, ensure_ascii=False))
        
    elif args.command == "news":
        news = client.get_news_data(args.symbol, limit=args.limit)
        print(json.dumps(news, indent=2, ensure_ascii=False))
        
    elif args.command == "system-status":
        status = client.get_system_status()
        print(json.dumps(status, indent=2, ensure_ascii=False))
        
    elif args.command == "logs":
        logs = client.list_logs(limit=args.limit)
        print(json.dumps(logs, indent=2, ensure_ascii=False))
        
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
