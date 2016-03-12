#####################################################################################
#                                   ADS-B RECEIVER                                  #
#####################################################################################
#                                                                                   #
#  A set of scripts created to automate the process of installing the software      #
#  needed to setup a Mode S decoder as well as feeders which are capable of         #
#  sharing your ADS-B results with many of the most popular ADS-B aggregate sites.  #
#                                                                                   #
#  Project Hosted On GitHub: https://github.com/jprochazka/adsb-receiver            #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015 Joseph A. Prochazka                                            #
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy      #
# of this software and associated documentation files (the "Software"), to deal     #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
# copies of the Software, and to permit persons to whom the Software is             #
# furnished to do so, subject to the following conditions:                          #
#                                                                                   #
# The above copyright notice and this permission notice shall be included in all    #
# copies or substantial portions of the Software.                                   #
#                                                                                   #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
# SOFTWARE.                                                                         #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

import json
import datetime

from oled.device import ssd1306, sh1106
from oled.render import canvas
from PIL import ImageDraw, ImageFont
from time import time, sleep


with open('/run/dump1090-mutability/aircraft.json') as aircraft_json:
    aircraft_data = json.load(aircraft_json)


def date_and_time():
    now = datetime.datetime.now()
    return now.strftime("%m/%d/%Y %I:%M %p")

def aircraft_total():
    return len(aircraft_data['aircraft'])

def aircraft_with_positions():
    with_positions = 0
    for aircraft in aircraft_data['aircraft']:
        if 'seen_pos' in aircraft:
            with_positions += 1
    return with_positions


def stats(oled):
    font = ImageFont.load_default()
    font2 = ImageFont.truetype('fonts/alert.ttf', 12)
    font3 = ImageFont.truetype('fonts/alert.ttf', 36)
    with canvas(oled) as draw:
        draw.text((0, 0), date_and_time(), font=font2, fill=255)
        draw.text((0, 14), "Total / With Positions", font=font2, fill=255)
        draw.text((0, 28), str(aircraft_total()) + "/" + str(aircraft_with_positions()), font=font3, fill=255)

def main():
    oled = ssd1306(port=1, address=0x3C)
    stats(oled)

if __name__ == "__main__":
    main()
