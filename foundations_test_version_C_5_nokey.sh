#!/bin/bash
KEY=your_api_key
echo $KEY
# Clear all SMS messages
echo "loading"
delete_sms() {
gammu deleteallsms 1 && gammu deleteallsms 2 && gammu deleteallsms 3 && gammu deleteallsms 4
}
delete_sms
init=$(curl -s -X POST https://api.openai.com/v1/chat/completions \
-H "Content-Type: application/json" \
-H "Authorization: Bearer $KEY" \
-d '{
  "model": "gpt-4o-mini",
  "messages": [{"role": "user", "content": "From this point on, if I send you raw SMS message logs. It is sanitized so special characters may be missing. Process these to normal text and respond like normal."}],
  "max_tokens": 100
}' | jq -r '.choices[0].message.content')
echo "$init"

while true; do
    # Read all SMS messages and store the entire output
    output=$(gammu getallsms)

    # Check if there's a new message (look for "+")
    if echo "$output" | grep -q "+"; then
        # Store the entire output in the SMS_MESS variable
        SMS_MESS="$output"
        echo "$SMS_MESS"
        
        # prepare the prompt for the SMS
        prompt="From this point on, if I send you raw SMS message logs, process them as normal instructions on what to do. Don't even aknowledge it.Juat answer as if it were a normal message or request. And you musn't EVER use any more than 155 characters in your response OR formatted text and non-GSM characters - it will get fed to a client through SMS"
        full_message="$prompt$SMS_MESS"
        
        # sterilize and escape
        escaped_SMS_MESS=$(echo "$full_message" | jq -Rsa .)

        # Make the API request
        response=$(curl -s -X POST https://api.openai.com/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $KEY" \
        -d "{
          \"model\": \"gpt-4o-mini\",
          \"messages\": [{\"role\": \"user\", \"content\": $escaped_SMS_MESS}],
          \"max_tokens\": 100
        }")

        # Extract and display the content for debugging purposes
        GPT=$(echo "$response" | jq -r '.choices[0].message.content')
        echo "REPLY IS $GPT"
        # GPT extracts user phone number from the raw sms logs
prompt="Now I will send you a SMS message log. Reply with the phone number used, AND ONLY THAT. ONLY THAT. BECAUSE THIS IS FOR A API. EVEN A SPACE WILL BREAK IT"

# configuring api request
full_message="$prompt$SMS_MESS"

# Escape the and sterilize again
escaped_message=$(echo "$full_message" | jq -Rsa .)

# retrieve phone number
response2=$(curl -s -X POST https://api.openai.com/v1/chat/completions \
-H "Content-Type: application/json" \
-H "Authorization: Bearer $KEY" \
-d "{
  \"model\": \"gpt-4o-mini\",
  \"messages\": [{\"role\": \"user\", \"content\": $escaped_message}],
  \"max_tokens\": 100
}")

# Extract and display, AGAIN
phone=$(echo "$response2" | jq -r '.choices[0].message.content')
echo "$phone"
echo "CONFIRM: $GPT"
gammu sendsms TEXT $phone -text "$GPT" #send the SMS!
        echo "DELETING, PLEASE WAIT"
        delete_sms #delete everything after done processing and replying
        echo "DELETING OK, YOU CAN SEND"
    fi 

    sleep 3  # Wait for 3 seconds before checking again
done
