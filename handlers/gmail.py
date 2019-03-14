import smtplib
import argparse
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText


def _compose_mail(emailfrom, emailto, cluster):
    msg = MIMEMultipart("alternative")
    msg["From"] = emailfrom
    msg["To"] = emailto
    msg["Subject"] = "Spot Termination Notification"
    text = """
        Hello,\n\n
        Your cluster {} has lost a spot instance.\n
        It has been drained to prevent internal errors but you should check it.
    \n""".format(cluster)
    msg.attach(MIMEText(text, "plain"))
    return msg


def _send(username, password, emailto, msg):
    server = smtplib.SMTP("smtp.gmail.com:587")
    server.starttls()
    server.login(username, password)
    server.sendmail(username, emailto.split(","), msg.as_string())
    server.quit()


def _parse_arguments():
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('-u', '--gmail-user', required=True)
    parser.add_argument('-p', '--gmail-pass', required=True)
    parser.add_argument('-t', '--to-address', required=True)
    parser.add_argument('-c', '--cluster-name', required=True)
    return parser.parse_args()


def send_gmail_notification():
    args = _parse_arguments()
    msg = _compose_mail(args.gmail_user, args.to_address, args.cluster_name)
    _send(args.gmail_user, args.gmail_pass, args.to_address, msg)


if __name__ == "__main__":
    send_gmail_notification()
