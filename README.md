# HeroHub
Build your GitHub commits on Heroku automatically.

**Note**: Only public repositories are supported as of now.

## Current Status
Everthing works. Need to look for leaks.

## Setting Up
**Note**: You need to have [node](http://www.nodejs.org) and [heroku toolbelt](https://toolbelt.heroku.com/) installed.

* Clone this repository.

* Run 'setup', i.e. `./setup`.

### For each of the repos that you would like to build commits automatically,
* Create a file `.deploy` in your root folder of your repository.
It should contain:

```
<provider> <app>: branch <branch>
<provider> <app>: hashtag <hashtag>
...
```

For example:

```
heroku herohub: branch production
heroku herohub-experimental: hashtag deploy-experimental
```

In your GitHub repo > Admin > Service Hooks, add a **WebHook URL** with the url, `http://<Your-Deployer-identifier>.heroku.com/deploy/github`. `<Your-Deployer-identifier>` is the name of the deployer app created by setup.

## Usage
You can trigger the deployment by either:

* Committing to a **branch** specified in the `.deploy` file and then pushing it to GitHub. 

* Mentioning a **hashtag** specified in the `.deploy` file in the commit description (example: `git commit -m "Fixed bugs #301 and #334. #deploy-experimental"`)and then pushing it to GitHub.


**Note:** One Deployer can be used for any number of apps within the same heroku account.