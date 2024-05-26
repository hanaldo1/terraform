import boto3, os
from dateutil import relativedelta
from datetime import datetime, timezone, timedelta

# Import WebClient from Python SDK (github.com/slackapi/python-slack-sdk)
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

def lambda_handler(event, context):
  KST = timezone(timedelta(hours=9))

  this_month = datetime.now(tz=KST)
  next_month = this_month + relativedelta.relativedelta(months=1)

  this_month_1st = this_month.strftime("%Y-%m-01")
  next_month_1st = next_month.strftime("%Y-%m-01")

  # Get bill using AWS Cost Explorer API
  try:
    client = boto3.client("ce")
    response = client.get_cost_and_usage(
      TimePeriod={"Start": this_month_1st, "End": next_month_1st},
      Granularity="MONTHLY",
      Metrics=["UnblendedCost"],
    )

    amount = response["ResultsByTime"][0]["Total"]["UnblendedCost"]["Amount"]
    this_month_bill = "%.3f" % float(amount)

    msg = f"{this_month_1st} ~ {next_month_1st} bill: $" + this_month_bill
    print(msg)

    # Send message to Slack channel
    client = WebClient(token=os.environ.get("SLACK_BOT_TOKEN"))
    result = client.chat_postMessage(
      channel=os.environ.get("SLACK_CHANNEL"), 
      text=msg
    )

    print(f"Slack post message result: {result['ok']}")
  except SlackApiError as e:
    print(f"Error posting message: {e}")
  except RuntimeError as e:
    print(f"Runtime error: {e}")