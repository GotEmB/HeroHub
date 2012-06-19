# HeroHub
Build your GitHub commits on Heroku automatically.

## Current Status
Nothing's implemented yet.

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

* Add `deploy.herohub@gmail.com` as a collaborator to your heroku app.

* Add an **environment variable** `hh-key` with a random string as its value.

* In Github, add an **HTTP Post** hook with the url, `http://deploy-repo.heroku.com/github/<hh-key>`. Where `<hh-key>` is the random string.

## Usage
You can trigger the deployment by either:

* Committing to a **branch** specified in the `.deploy` file and then pushing it to GitHub. 

* Mentioning a **hashtag** specified in the `.deploy` file in the commit and then pushing it to GitHub.