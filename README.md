# heroku war plugin

This plugin adds some commands to the heroku gem to allow it to deploy a .war to an application

## Installation

To install:

    $ heroku plugins:install https://github.com/lstoll/heroku-war.git

## Commands

### Deploy

    $ heroku war:deploy -a appname filename.war
    
This will deploy the given .war file in a tomcat runner.
