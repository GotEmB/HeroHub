# HeroHub
Build your GitHub commits on Heroku automatically.

## Current Status
Nothing's implemented yet.

This README *might* make no sense as of now.

## Setting Up
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

* Clone this repository and name it, say `myDeployer`.

* Run 'setup-repo'.

* In Github, add an **HTTP Post** hook with the url, `http://<myDeployer-identifier>.heroku.com/deploy`. `<myDeployer-identifier>` is the name of the deployer app created by setup-repo.

## Usage
You can trigger the deployment by either:

* Committing to a **branch** specified in the `.deploy` file and then pushing it to GitHub. 

* Mentioning a **hashtag** specified in the `.deploy` file in the commit and then pushing it to GitHub.


**Note:** One DeployerApp can be used for any number of apps within the same heroku account.