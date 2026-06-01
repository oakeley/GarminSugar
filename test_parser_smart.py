def extract_time_as_seconds(json_string):
    key = '"time"'
    idx = json_string.find(key)
    if idx == -1:
        return None
    
    start = idx + len(key)
    val_str = ""
    found_digit = False
    
    limit = start + 30
    if limit > len(json_string):
        limit = len(json_string)
        
    for i in range(start, limit):
        char = json_string[i]
        is_digit = char.isdigit()
        
        if not found_digit:
            if is_digit:
                found_digit = True
                val_str += char
        else:
            if is_digit:
                val_str += char
            else:
                break
                
    # NEW LOGIC SIMULATION
    if len(val_str) >= 13:
        val_str = val_str[:-3]
        
    if len(val_str) > 0:
        return int(val_str)
    return None

test_cases = [
    '{"bg": {"time": 1768580367026}}',         # MS (13 digits)
    '{"time": 1768580367}',                     # Seconds (10 digits) -> Should equal above
    '{"time":1768580367026}',                  # MS Compact
    '{"time": 1}'                               # Short (incorrect but shouldn't crash)
]

for t in test_cases:
    print(f"Input: {t} -> Output: {extract_time_as_seconds(t)}")
