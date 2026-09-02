import asyncio
import urllib.request
import json
import time

# --- YAHAN APNI DETAILS DALO ---
TELEGRAM_BOT_TOKEN = "8854368270:AAFYyq_mHrI_HYSkIduwuELvAQ1Zn_99K3w" 
TELEGRAM_CHAT_ID = "8330160168"
# --------------------------------------

HEADERS = {
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Connection': 'keep-alive',
    'Origin': 'https://ayhbaw55.com',
    'Referer': 'https://ayhbaw55.com/',
    'Sec-Fetch-Dest': 'empty',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Site': 'cross-site',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36'
}

GAME_MODES = {
    "30 Sec": "WinGo_30S",
    "1 Min": "WinGo_1M", 
    "3 Min": "WinGo_3M",
    "5 Min": "WinGo_5M"
}

def send_telegram_message_sync(message):
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
    current_ts = int(time.time() * 1000)
    url = f'https://draw.ar-lottery01.com/WinGo/{game_code}/GetHistoryIssuePage.json?ts={current_ts}'
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status == 200:
                data = json.loads(response.read().decode())
                return data.get('data', {}).get('list', [])
    except Exception as e:
        print(f"⚠️ [{game_code}] Fetch Error: {e}")
    return None

def predict_next_period(history_list, game_name):
    if not history_list or len(history_list) < 3:
        return None, None
        
    latest_result = history_list[0]
    last_issue = latest_result.get('issueNumber')
    last_number = latest_result.get('number')
    
    # Agle period ka number calculate karna taaki user ko clear rahe
    try:
        next_issue = str(int(last_issue) + 1)
    except:
        next_issue = "Next"
    
    recent_sizes = ["Big" if int(item['number']) > 4 else "Small" for item in history_list[:3]]
    last_size = recent_sizes[0]
    
    # Tumhara Logic
    if recent_sizes.count("Small") >= 2:
        prediction = "Big 🟩"
    elif recent_sizes.count("Big") >= 2:
        prediction = "Small 🟥"
    else:
        prediction = "Wait for pattern ⏸️"

    message = (
        f"🎮 **{game_name} Game**\n"
        f"✅ Past Period `{last_issue}` Result: **{last_number} ({last_size})**\n"
        f"➖➖➖➖➖➖➖➖\n"
        f"⏳ Place Bet For: `{next_issue}`\n"
        f"🔮 Prediction: **{prediction}**"
    )
    return message, last_issue

async def monitor_single_game(game_name, game_code, polling_interval):
    last_processed_period = None
    while True:
        history_data = await asyncio.to_thread(fetch_game_history_sync, game_code)
        if history_data:
            latest_period = history_data[0].get('issueNumber')
            if latest_period != last_processed_period:
                # Jab pehli baar script chalegi, toh purane data ka spam na aaye isliye ye check
                if last_processed_period is not None:
                    prediction_msg, current_issue = predict_next_period(history_data, game_name)
                    if prediction_msg:
                        print(f"⚡ [{game_name}] Fast prediction sent for {current_issue}!")
                        await asyncio.to_thread(send_telegram_message_sync, prediction_msg)
                
                last_processed_period = latest_period
        
        # Fast polling interval se bot turant detect karega
        await asyncio.sleep(polling_interval)

async def hermes_main_engine():
    print("🚀 Ultra-Fast Local Prediction Bot Started!")
    tasks = [
        # Ab wait time bohot kam kar diya hai
        monitor_single_game("30 Sec", GAME_MODES["30 Sec"], 2),  # Har 2 second me check
        monitor_single_game("1 Min", GAME_MODES["1 Min"], 3),    # Har 3 second me check
        monitor_single_game("3 Min", GAME_MODES["3 Min"], 5),    # Har 5 second me check
        monitor_single_game("5 Min", GAME_MODES["5 Min"], 10)    # Har 10 second me check
    ]
    await asyncio.gather(*tasks)

if __name__ == "__main__":
    asyncio.run(hermes_main_engine())
