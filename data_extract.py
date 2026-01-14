import json
import pandas as pd
import requests

def process_glucose_data(json_input=None, url=None):
    # 1. Load Data
    if url:
        try:
            response = requests.get(url)
            response.raise_for_status()
            data = response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error fetching data from web: {e}")
            return None, None, None, None, None, pd.DataFrame()
    elif json_input:
        data = json.loads(json_input)
    else:
        print("No input provided.")
        return None, None, None, None, None, pd.DataFrame()
    
    # 2. Extract Basic Info
    battery_level = data.get('status', {}).get('bat')
    bg_info = data.get('bg', {})
    trend = bg_info.get('trend')
    val = bg_info.get('val')
    
    # 3. Extract Graph Data
    all_points = []
    high_threshold = None
    low_threshold = None
    
    try:
        lines = data.get('graph', {}).get('lines', [])
        
        for line in lines:
            name = line.get('name')
            points = line.get('points', [])
            
            # --- key change: Include "high" and "low" data lines ---
            # We ignore colors and filter by name.
            if name in ["inRange", "high", "low"]:
                all_points.extend(points)
                
            # Extract High Threshold
            elif name == "lineHigh" and points:
                high_threshold = points[0][1] 
                
            # Extract Low Threshold
            elif name == "lineLow" and points:
                low_threshold = points[0][1]
        
        # 4. Create and Sort DataFrame
        if all_points:
            df = pd.DataFrame(all_points, columns=['Timestamp', 'Glucose_Value'])
            # Sort by Timestamp. 
            # ascending=False puts the newest records (larger timestamp) first. 
            # Change to True if you want oldest first.
            df = df.sort_values(by='Timestamp', ascending=False).reset_index(drop=True)
        else:
            df = pd.DataFrame(columns=['Timestamp', 'Glucose_Value'])
            
    except (KeyError, IndexError, TypeError) as e:
        print(f"Error parsing graph data: {e}")
        df = pd.DataFrame()

    return battery_level, trend, val, high_threshold, low_threshold, df

# --- Usage Example ---

# Option A: Use the JSON string provided
json_payload = """
{"bg":{"delta":"+0.1","isHigh":false,"isLow":false,"isStale":false,"time":1768215338263,"trend":"Flat","val":"10.2"},"external":{},"graph":{"end":58940543,"fuzzer":30000,"lines":[{"color":"0xFFBB33","name":"high","points":[[58940512,10.1],[58940508,10.2],[58940504,10.6],[58940500,11.1],[58940496,10.8],[58940492,10.4],[58940488,10.1],[58940484,10.2],[58940480,10.2],[58940476,10.1]]},{"color":"0xFFFFFF","name":"inRange","points":[[58940472,9.6],[58940468,9.1],[58940464,8.8],[58940460,8.8],[58940456,8.9],[58940452,8.7],[58940448,8.3],[58940444,7.8],[58940440,7.2],[58940436,6.8],[58940432,6.5],[58940428,6.2],[58940424,6.1],[58940420,6.0],[58940416,5.8],[58940412,5.7],[58940408,5.5],[58940404,5.5],[58940400,5.5],[58940396,5.5],[58940392,5.6],[58940388,5.6],[58940384,5.5],[58940380,5.5],[58940376,5.7],[58940372,5.7],[58940368,5.7],[58940364,5.4],[58940360,5.2],[58940356,5.2],[58940352,5.1],[58940348,5.1],[58940344,5.2],[58940340,5.5],[58940336,5.5],[58940332,5.2],[58940328,5.1],[58940324,5.3],[58940320,5.2],[58940316,5.2],[58940312,5.2],[58940308,5.4],[58940304,5.4],[58940300,5.4],[58940296,5.4],[58940292,5.5],[58940288,5.6],[58940284,5.7],[58940280,5.8],[58940276,6.0],[58940272,6.0],[58940268,5.8],[58940264,5.7],[58940260,5.8],[58940256,6.1],[58940252,6.1],[58940248,6.1],[58940244,6.2],[58940240,6.2],[58940236,6.4],[58940232,6.2],[58940228,6.2],[58940224,6.2],[58940220,6.2],[58940216,6.3],[58940212,6.6],[58940208,6.5],[58940204,6.4],[58940200,6.5],[58940196,7.0],[58940192,7.0],[58940188,7.1],[58940184,7.0],[58940180,6.6],[58940176,6.5],[58940172,6.5],[58940168,6.4],[58940164,6.6],[58940160,7.1],[58940156,7.2],[58940152,7.1],[58940148,7.0],[58940144,6.9],[58940140,7.1],[58940136,7.2],[58940132,7.1],[58940128,7.1],[58940124,7.2],[58940120,7.5],[58940116,7.6],[58940112,7.5],[58940108,6.8],[58940104,6.5],[58940100,6.6],[58940096,6.6],[58940092,6.5],[58940088,6.5],[58940084,6.6],[58940080,6.6],[58940076,6.6],[58940072,6.6],[58940068,6.6],[58940064,6.6],[58940060,6.5],[58940056,6.3],[58940052,6.2],[58940048,6.2],[58940044,6.2],[58940040,5.9],[58940036,5.6],[58940032,5.5]]},{"color":"0xC30909","name":"lineLow","points":[[58940032,3.9],[58940544,3.9]]},{"color":"0xFFBB33","name":"lineHigh","points":[[58940032,10.0],[58940544,10.0]]}],"start":58940031},"pump":{"bat":0.0,"iob":0.0,"reservoir":0.0},"status":{"bat":78,"isMgdl":false,"now":1768215372049},"treatment":{}}
"""
# bat, trend, val, high, low, df = process_glucose_data(json_input=json_payload)

# Option B: Use Web Request (Uncomment to use)
bat, trend, val, high, low, df = process_glucose_data(url="http://localhost:29863/info.json?graph=1")

# --- Results ---
print(f"Battery: {bat}%")
print(f"Trend: {trend}")
print(f"Current Value: {val}")
print(f"High Threshold: {high}")
print(f"Low Threshold: {low}")
print("-" * 30)
print("First 5 rows of DataFrame:")
print(df.head(5))
print("-" * 30)
print("Last 5 rows of DataFrame:")
print(df.tail(5))