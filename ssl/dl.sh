import time
import requests
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from telegram import Bot

# 填写以下信息
URL = "http://example.com/login"  # 登录页面的URL
TELEGRAM_BOT_TOKEN = "7904127530:AAEvop-tjPB9C_yNTsdjuNDwIN5oiuqNtxk"  # Telegram 机器人的API Token
TELEGRAM_CHAT_ID = "7816805338"  # Telegram 频道/群组/个人的Chat ID
ACCOUNTS = [
    {"username": "xcszhql", "password": "oUmKoDkvd2Dn"},
    {"username": "vyzgornsth", "password": "pass2"},
    # 添加更多账号...
]

# 设置 Telegram 机器人
bot = Bot(token=TELEGRAM_BOT_TOKEN)

# 设置 Chrome 浏览器驱动
chrome_options = Options()
chrome_options.add_argument("--headless")  # 无头模式
chrome_options.add_argument("--disable-gpu")

# 启动浏览器
driver = webdriver.Chrome(service=Service("/path/to/chromedriver"), options=chrome_options)

def send_telegram_message(message):
    bot.send_message(chat_id=TELEGRAM_CHAT_ID, text=message)

def login_and_notify(account):
    driver.get(URL)
    
    # 根据网页结构修改以下字段
    username_input = driver.find_element(By.NAME, "username")  # 假设用户名字段的name属性为 "username"
    password_input = driver.find_element(By.NAME, "password")  # 假设密码字段的name属性为 "password"
    login_button = driver.find_element(By.XPATH, '//button[@type="submit"]')  # 假设登录按钮是提交按钮
    
    # 输入用户名和密码
    username_input.send_keys(account['username'])
    password_input.send_keys(account['password'])
    
    # 点击登录按钮
    login_button.click()
    
    time.sleep(3)  # 等待页面加载

    # 检查是否成功登录，假设登录后页面中有“Welcome”字样
    if "Welcome" in driver.page_source:
        send_telegram_message(f"账号 {account['username']} 登录成功！")
    else:
        send_telegram_message(f"账号 {account['username']} 登录失败。")

def main():
    for account in ACCOUNTS:
        login_and_notify(account)
        random_seconds = random.randint(100, 200)  # 随机生成等待时间（30分钟到1小时之间）
        print(f"等待 {random_seconds} 秒后登录下一个账号...")
        time.sleep(random_seconds)  # 每个账号登录后等待随机时间（30分钟到1小时）


    # 完成所有登录后，退出浏览器
    driver.quit()

if __name__ == "__main__":
    main()
