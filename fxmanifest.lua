fx_version 'cerulean'
game 'gta5'

author 'ModoraLabs'
description 'Modora FiveM Admin - Server stats and angle system'
version '1.09'

dependency 'screenshot-basic'

client_scripts {
    'config.lua',
    'client/main.lua'
}

server_scripts {
    'config.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/styles.css',
    'html/app.js'
}