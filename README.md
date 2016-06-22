[![Otouto version](https://img.shields.io/badge/Otouto%20Version-3.10-blue.svg?style=flat-square&link=https://github.com/topkecleon/otouto&link=https://github.com/topkecleon/otouto/commit/101eb70eaefaf8711ef49e5a3a89c79e601ba1f4)]() [![Cryonite version](https://img.shields.io/badge/Cryonite%20Version-0.3-blue.svg?style=flat-square&link=https://github.com/topkecleon/otouto&link=https://github.com/topkecleon/otouto/commit/101eb70eaefaf8711ef49e5a3a89c79e601ba1f4)]() [![License](https://img.shields.io/badge/License-GNU-blue.svg?link=https://github.com/joostlek/Cryonite/blob/master/LICENSE&style=flat-square)]() [![Wiki](https://img.shields.io/badge/Wiki-Not%20ready-red.svg?style=flat-square&link=https://github.com/joostlek/Cryonite/wiki)]()


---------
Cryonite
===================


Hey there, welcome to the Cryonite Github. 
Cryonite is a Telegram bot based on [Otouto](https://github.com/topkecleon/otouto "Otouto") by [Topkecleon](https://github.com/topkecleon/ "Topkecleon"). 

Cryonite is free software; you are free to redistribute it and/or modify it under the terms of the GNU Affero General Public License, version 3. See LICENSE for details.

Something to ask? Come check out one of these links.

[![Grouplink](https://img.shields.io/badge/Telegram-Group-blue.svg?style=flat-square&link=https://telegram.me/joinchat/AkYKjD7vFuZTU8ooR_WfKA)]()  [![Grouplink](https://img.shields.io/badge/Telegram-Channel-blue.svg?style=flat-square&link=https://telegram.me/cryonite)]()  [![Grouplink](https://img.shields.io/badge/Telegram-Bot-blue.svg?style=flat-square&link=https://telegram.me/cryonitebot)]()

----------


Installation
-------------

Want to run your own version of Cryonite? Make sure you have a linux system ready to go.
Then run this code to get all the required files:
`sudo apt-get update && sudo apt-get install libreadline-dev libconfig-dev libssl-dev lua5.2 liblua5.2-dev libevent-dev make unzip git redis-server g++ libjansson-dev libpython-dev expat libexpat1-dev -y && git clone https://github.com/joostlek/cryonite.git && sudo apt-get install lua5.2 && sudo apt-get install lua-sec lua-socket`

You still need [dkjson.lua](http://dkolf.de/src/dkjson-lua.fsl/home "dkjson") and [multipart-post.lua](https://github.com/catwell/lua-multipart-post "multipart-Post"). Request a bot token at [BotFather](https://telegram.me/BotFather "BotFather"), then edit config.lua and paste the bot token in `bot_api_key = '',`. Run Launch.sh to make the basic bot run. Want to use the administration side of the bot? Run Tg-Install.sh first, when it's finished, run Tg-Launch.sh. Now you can enter your own phone number and then you will receive a verification message at that specific account, enter the code in the console and you will see your messages appearing. Now you can use your administration bot!