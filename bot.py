import asyncio
import aiohttp
import time
import os

# Telegram details ab Render environment se aayengi
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
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'cross-site',
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36'
}

GAME_MODES = {
    "30 Sec": "WinGo_30S",
    "1 Min": "WinGo_1M", 
    "3 Min": "WinGo_3M",
    "5 Min": "WinGo_5M"
}

async def send_telegram_message(session, message):
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        return
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {"chat_id": TELEGRAM_CHAT_ID, "text": message, "parse_mode": "Markdown"}
    try:
        await session.post(url, json=payload)
    except Exception as e:
        pass

async def fetch_game_history(session, game_code):
    current_ts = int(time.time() * 1000)
    url = f'https://draw.ar-lottery01.com/WinGo/{game_code}/GetHistoryIssuePage.json?ts={current_ts}'
    try:
        async with session.get(url, headers=HEADERS) as response:
            if response.status == 200:
                data = await response.json()
                return data.get('data', {}).get('list', [])
    except Exception as e:
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

async def monitor_single_game(session, game_name, game_code, polling_interval):
    last_processed_period = None
    while True:
        history_data = await fetch_game_history(session, game_code)
        if history_data:
            latest_period = history_data[0].get('issueNumber')
            if latest_period != last_processed_period:
                prediction_msg, current_issue = predict_next_period(history_data, game_name)
                if prediction_msg:
                    print(f"[{game_name}] Prediction sent for {latest_period}")
                    await send_telegram_message(session, prediction_msg)
                last_processed_period = latest_period
        await asyncio.sleep(polling_interval)

async def hermes_main_engine():
    async with aiohttp.ClientSession() as session:
        print("🚀 Background Prediction Bot Started!")
        tasks = [
            monitor_single_game(session, "30 Sec", GAME_MODES["30 Sec"], polling_interval=10),
            monitor_single_game(session, "1 Min", GAME_MODES["1 Min"], polling_interval=15),
            monitor_single_game(session, "3 Min", GAME_MODES["3 Min"], polling_interval=30),
            monitor_single_game(session, "5 Min", GAME_MODES["5 Min"], polling_interval=45)
        ]
        await asyncio.gather(*tasks)

if __name__ == "__main__":
    asyncio.run(hermes_main_engine())
