import json
import asyncio
from pyppeteer import launch
from datetime import datetime, timedelta
import random
import requests
import os

# 直接在脚本中设置 Telegram Bot Token 和 Chat ID
TELEGRAM_BOT_TOKEN = '7904127530:AAEvop-tjPB9C_yNTsdjuNDwIN5oiuqNtxk'  # 替换为你的 Telegram Bot Token
TELEGRAM_CHAT_ID = '7816805338'      # 替换为你的 Telegram Chat ID

# 账户信息，直接写在脚本中
accounts = [
    {
        "username": "xcszhql",
        "password": "oUmKoDkvd2Dn",
        "panel": "panel15.serv00.com"
    },
    {
        "username": "vyzgornsth",
        "password": "password2",
        "panel": "panel15.serv00.com"
    },
    # 你可以继续添加更多的账号信息
]

# 格式化时间为 ISO 格式
def format_to_iso(date):
    return date.strftime('%Y-%m-%d %H:%M:%S')

# 延时函数
async def delay_time(ms):
    await asyncio.sleep(ms / 1000)

# 全局浏览器实例
browser = None

# telegram消息
message = ""

# 登录函数
async def login(username, password, panel):
    global browser

    page = None  # 确保 page 在任何情况下都被定义
    serviceName = 'ct8' if 'ct8' in panel else 'serv00'
    try:
        if not browser:
            browser = await launch(headless=True, args=['--no-sandbox', '--disable-setuid-sandbox'])

        page = await browser.newPage()
        url = f'https://{panel}/login/?next=/'
        await page.goto(url)

        # 清空并输入用户名和密码
        username_input = await page.querySelector('#id_username')
        if username_input:
            await page.evaluate('''(input) => input.value = ""''', username_input)

        await page.type('#id_username', username)
        await page.type('#id_password', password)

        login_button = await page.querySelector('#submit')
        if login_button:
            await login_button.click()
        else:
            raise Exception('无法找到登录按钮')

        await page.waitForNavigation()

        # 检查是否登录成功
        is_logged_in = await page.evaluate('''() => {
            const logoutButton = document.querySelector('a[href="/logout/"]');
            return logoutButton !== null;
        }''')

        return is_logged_in

    except Exception as e:
        print(f'{serviceName}账号 {username} 登录时出现错误: {e}')
        return False

    finally:
        if page:
            await page.close()

# 显式的浏览器关闭函数
async def shutdown_browser():
    global browser
    if browser:
        await browser.close()
        browser = None

# 主函数
async def main():
    global message

    for account in accounts:
        username = account['username']
        password = account['password']
        panel = account['panel']

        serviceName = 'ct8' if 'ct8' in panel else 'serv00'
        is_logged_in = await login(username, password, panel)

        now_beijing = format_to_iso(datetime.utcnow() + timedelta(hours=8))
        if is_logged_in:
            message += f"✅*{serviceName}*账号 *{username}* 于北京时间 {now_beijing} 登录面板成功！\n\n"
            print(f"{serviceName}账号 {username} 于北京时间 {now_beijing} 登录面板成功！")
        else:
            message += f"❌*{serviceName}*账号 *{username}* 于北京时间 {now_beijing} 登录失败\n\n❗请检查*{username}*账号和密码是否正确。\n\n"
            print(f"{serviceName}账号 {username} 登录失败，请检查{serviceName}账号和密码是否正确。")

        delay = random.randint(1000, 8000)
        await delay_time(delay)
        
    message += f"🔚脚本结束，如有异常点击下方按钮👇"
    await send_telegram_message(message)
    print(f'所有{serviceName}账号登录完成！')

    # 退出时关闭浏览器
    await shutdown_browser()

# 发送 Telegram 消息
async def send_telegram_message(message):
    # 使用 Markdown 格式
    formatted_message = f"""
*🎯 serv00&ct8自动化保号脚本运行报告*

🕰 *北京时间*: {format_to_iso(datetime.utcnow() + timedelta(hours=8))}

⏰ *UTC时间*: {format_to_iso(datetime.utcnow())}

📝 *任务报告*:

{message}

    """

    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {
        'chat_id': TELEGRAM_CHAT_ID,
        'text': formatted_message,
        'parse_mode': 'Markdown',  # 使用 Markdown 格式
        'reply_markup': {
            'inline_keyboard': [
                [
                    {
                        'text': '问题反馈❓',
                        'url': 'https://t.me/yxjsjl'  # 点击按钮后跳转到问题反馈的链接
                    }
                ]
            ]
        }
    }
    headers = {
        'Content-Type': 'application/json'
    }

    try:
        response = requests.post(url, json=payload, headers=headers)
        if response.status_code != 200:
            print(f"发送消息到Telegram失败: {response.text}")
    except Exception as e:
        print(f"发送消息到Telegram时出错: {e}")

# 执行脚本
if __name__ == '__main__':
    asyncio.run(main())
