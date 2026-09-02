import asyncio
import urllib.request
import json
import time
import os

# Telegram details Render environment se aayengi
TELEGRAM_BOT_TOKEN = os.environ.get("PREDICTION_BOT_TOKEN")
TELEGRAM_CHAT_ID = os.environ.get("MY_CHAT_ID")

HEADERS = {
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'en-US,en;q=0.9',
    'origin': 'https://ayhbaw55.com',
    'referer': 'https://ayhbaw55.com/',
    'sec-ch-ua': '"Not=A?Brand";v="99", "Google Chrome";v="151", "Chromium";v="151"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36'
}

GAME_MODES = {
    "30 Sec": "WinGo_30S",
    "1 Min": "WinGo_1M", 
    "3 Min": "WinGo_3M",
    "5 Min": "WinGo_5M"
}

def send_telegram_message_sync(message):
    """Telegram par message bhejne ka built-in function"""
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        return
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = json.dumps({"chat_id": TELEGRAM_CHAT_ID, "text": message, "parse_mode": "Markdown"}).encode('utf-8')
    req = urllib.request.Request(url, data=payload, headers={'Content-Type': 'application/json'})
    try:
        urllib.request.urlopen(req, timeout=5)
    except Exception:
        pass

def fetch_game_history_sync(game_code):
    """Server se data lane ka built-in function"""
    current_ts = int(time.time() * 1000)
    url = f'https://draw.ar-lottery01.com/WinGo/{game_code}/GetHistoryIssuePage.json?ts={current_ts}'
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                data = json.loads(response.read().decode())
                return data.get('data', {}).get('list', [])
    except Exception:
        pass
    return None

def predict_next_period(history_list, game_name):
    if not history_list or len(history_list) < 3:
        return None, None
        
    latest_result = history_list[0]
    last_issue = latest_result.get('issueNumber')
    
    recent_sizes = ["Big" if int(item['number']) > 4 else "Small" for item in history_list[:3]]
    
    if recent_sizes.count("Small") >= 2:
        prediction = "Big 🟩"
    elif recent_sizes.count("Big") >= 2:
        prediction = "Small 🟥"
    else:
        prediction = "Wait for pattern ⏸️"

    message = (
        f"🎮 **{game_name} Game**\n"
        f"✅ Period: `{last_issue}` Completed\n"
        f"🔮 Next Prediction: **{prediction}**"
    )
    return message, last_issue

async def monitor_single_game(game_name, game_code, polling_interval):
    last_processed_period = None
    while True:
        # asyncio.to_thread use kiya taaki background me smoothly chale
        history_data = await asyncio.to_thread(fetch_game_history_sync, game_code)
        
        if history_data:
            latest_period = history_data[0].get('issueNumber')
            if latest_period != last_processed_period:
                prediction_msg, current_issue = predict_next_period(history_data, game_name)
                if prediction_msg:
                    print(f"[{game_name}] Prediction sent for {latest_period}")
                    await asyncio.to_thread(send_telegram_message_sync, prediction_msg)
                last_processed_period = latest_period
                
        await asyncio.sleep(polling_interval)

async def hermes_main_engine():
    print("🚀 Background Prediction Bot Started (No external dependencies)!")
    tasks = [
        monitor_single_game("30 Sec", GAME_MODES["30 Sec"], 10),
        monitor_single_game("1 Min", GAME_MODES["1 Min"], 15),
        monitor_single_game("3 Min", GAME_MODES["3 Min"], 30),
        monitor_single_game("5 Min", GAME_MODES["5 Min"], 45)
    ]
    await asyncio.gather(*tasks)

if __name__ == "__main__":
    asyncio.run(hermes_main_engine())
