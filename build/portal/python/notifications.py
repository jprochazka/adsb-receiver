#!/usr/bin/python

#================================================================================#
#                             ADS-B FEEDER PORTAL                                #
# ------------------------------------------------------------------------------ #
# Copyright and Licensing Information:                                           #
#                                                                                #
# The MIT License (MIT)                                                          #
#                                                                                #
# Copyright (c) 2015-2016 Joseph A. Prochazka                                    #
#                                                                                #
# Permission is hereby granted, free of charge, to any person obtaining a copy   #
# of this software and associated documentation files (the "Software"), to deal  #
# in the Software without restriction, including without limitation the rights   #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell      #
# copies of the Software, and to permit persons to whom the Software is          #
# furnished to do so, subject to the following conditions:                       #
#                                                                                #
# The above copyright notice and this permission notice shall be included in all #
# copies or substantial portions of the Software.                                #
#                                                                                #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR     #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,       #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE    #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER         #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE  #
# SOFTWARE.                                                                      #
#================================================================================#


##############################################################
# TODO:                                                      #
#------------------------------------------------------------#
# When no flights are seen a JSON error is encountered.      #
# Send a tweet to Twitter when a flight is seen.             #
# Add pip install python-twitter to the install script.      #
# Update the lastMessageCount using the API.                 #
# Add support for MySQL.                                     #
# Add support for SQLite.                                    #
##############################################################


import json
import urllib
import urllib2
import socket
import smtplib
import twitter

from xml.dom import minidom
import xml.etree.ElementTree as ET

# Temporary variables for testing.
portal_url = "http://172.17.2.148"
debug_script = "true"
send_email = "false"
send_tweet = "false"


###############################################
## GATHER XML DATA


# Get the portal settings from the settings.xml file.
config_tree = ET.parse("/var/www/html/data/settings.xml")
config_root = config_tree.getroot()
for setting in config_root.findall('setting'):
    if setting.find('name').text == "enableEmailNotifications":
        setting_enable_email_notifications = setting.find('value').text
    if setting.find('name').text == "emailNotificationAddresses":
        setting_enable_email_notifications = setting.find('value').text
    if setting.find('name').text == "enableTwitterNotifications":
        setting_enable_twitter_notifications = setting.find('value').text
    if setting.find('name').text == "twitterUserName":
        setting_twitter_user_name = setting.find('value').text
    if setting.find('name').text == "twitterConsumerKey":
        setting_twitter_cosumer_key = setting.find('value').text
    if setting.find('name').text == "twitterConsumerSecret":
        setting_twitter_consumer_secret = setting.find('value').text
    if setting.find('name').text == "twitterAccessToken":
        setting_twitter_access_token = setting.find('value').text
    if setting.find('name').text == "twitterAccessTokenSecret":
        setting_twitter_access_token_secret = setting.find('value').text

# Display setting variables if script debuging is turned on.
if debug_script == "true":
    print "setting_enable_email_notifications: ",setting_enable_email_notifications
    print "setting_email_notification_addressees: ",setting_email_notification_addressees
    print "setting_enable_twitter_notifications: ",setting_enable_twitter_notifications
    print "setting_twitter_user_name: ",setting_twitter_user_name
    print "setting_twitter_cosumer_key: ",setting_twitter_cosumer_key
    print "setting_twitter_consumer_secret: ",setting_twitter_consumer_secret
    print "setting_twitter_access_token: ",setting_twitter_access_token
    print "setting_twitter_access_token_secret: ",setting_twitter_access_token_secret
    print "--------------------------------------------------"

# Get flights to send notifications for from the notifications.xml file.
doc = minidom.parse("/var/www/html/data/notifications.xml")
flights = doc.getElementsByTagName("flight")


###############################################
## SEND NOTIFICATION(S) IF FLIGHTS ARE FOUND


# Get notification JSON from the portal.
response = urllib2.urlopen(portal_url,"/api/notifications.php?type=flights")
flights_seen = json.load(response)

for flight in flights:
    name = flight.getElementsByTagName("name")[0]
    lastMessageCount = flight.getElementsByTagName("lastMessageCount")[0]

    for i in flights_seen['tracking']:
        if name.firstChild.data.strip() == i['flight'] and lastMessageCount.firstChild.data.strip() > i['lastMessageCount']:

            if send_emails == "true":
                # Send emails to the administrators telling them this flight is being tracked.
                sender = 'noreply@adsbreceiver.net'
                receivers = ['joe@swiftbyte.com']
                message = """From: From ADS-B Receiver <noreply@adsbreceiver.net>
To: To Administrator <joe@swiftbyte.com>
MIME-Version: 1.0
Content-type: text/html
Subject: ADS-B Receiver Flight Notification

<h1>ADS-B Receiver Flight Notification</h1>
<b>The following flight is currently being tracked.</b>
<p>{flight}</p>
<a href="http://{ip_address}/dump1090.php">Click here</a> to view this and any other flights currently being tracked by this receiver. 
""".format(flight=name.firstChild.data.strip(), ip_address=socket.gethostbyname(socket.gethostname()))
                try:
                    smtpObj = smtplib.SMTP('localhost')
                    smtpObj.sendmail(sender, receivers, message)

                    if debug_script == "true":
                        ### ADD EMAIL TO THIS LINE
                        print "Successfully sent a notification for flight",name.firstChild.data.strip()," to email address --- ADD EMAIL ADDRESS HERE ---." 

                except SMTPException:
                    print "Error: unable to send email"

            if send_tweet == "true":
                # Send a tweet to Twitter saying this flight is being tracked.
                # https://github.com/bear/python-twitter
                message = "The following flight is currently being tracked: {flight}".format(flight=name.firstChild.data.strip())
                api = twitter.Api(consumer_key=setting_twitter_cosumer_key, consumer_secret=setting_twitter_consumer_secret, access_token_key=setting_twitter_access_token, access_token_secret=setting_twitter_access_token_secret)
                try:
                    status = api.PostUpdate(message)
                    print "Successfully sent tweet"
                except UnicodeDecodeError:
                    print "Error: unable to send tweet"


###############################################
## UPDATE THE FLIGHTS LASTMESSAGECOUNT


        if name.firstChild.data.strip() == i['flight']:
            update_data = [('flight',i['flight']),('messages','0')]
            update_data = urllib.urlencode(update_data)
            request = urllib2.Request(portal_url,"/api/notifications.php?type=update", update_data)
            request.add_header("Content-type", "application/x-www-form-urlencoded")
            response = urllib2.urlopen(request)
            json_response = json.load(response)

            ### READ JSON FOR RESPONSE

            if debug_script == "true":
                print "lastMessage count for ",i['flight']," updated to ",i['lastMessageCount'],"."        
