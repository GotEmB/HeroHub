# Depreciated. Rewriting from scratch. --> web2.coffee
# Load Modules
express	= require "express"
crypto	= require "crypto"
http	= require "http"
fs		= require "fs"
coffee	= require "coffee"
fluent	= require "./fluent"
request	= require "request"
md5		= require "MD5"
child_p	= require "child_process"

# Helper Methods
String::getHashtags -> @match /(#[A-Za-z0-9-_]+)/g

doTheStuff = (targetRepo, rootTreeURL) ->
	cloneRepo = (repo, folder) ->
		stderr = ""
		git = child_p.spawn "git", ["clone", repo, folder]
		git.stderr.on (data) -> stderr += data
		await git.exit.on defer exitcode
		if stderr.indexOf("fatal") isnt -1
			success:	false
			message:	stderr
		else
			success:	true
	recSrc = (treeUrl, folder) ->
		await request treeUrl, defer err, tree
		tree.forEach (node) ->
			if node.type is "tree"
				nf = "#{folder}/#{node.path}"
				await fs.mkdir nf, "0777", defer err
				recSrc node.url, nf
			else if node.type is "blob"
				await fs.writeFile "#{folder}/#{node.path}", new Buffer(node.content, node.encoding), defer err
	pushRepo = (repo, folder) ->
		return # ...
	folder = "sandbox/" + md5 rootTree + do (new Date).getTime
	cR = cloneRepo targetRepo, folder
	return cR unless cR.success
	recSrc rootTreeURL, folder
	pushRepo targetRepo, folder

# Setup Server
server = do express.createServer
server.configure ->
	server.use do express.logger
	server.use do express.bodyParser

# Receive Post Requests – GitHub
server.post "/github/:ss-key", (req, res, next) ->
	func = ->
		payload = req.body.payload
		return "Private repositories are currently not supported." if payload.repository.private
		ghPath = "https://api.github.com/repos/#{payload.repository.owner.name}/#{payload.repository.name}"
		ret = ""
		for commit in payload.commits # Bad Code: Need to first sort by datestamps in descending order.
			await request "#{ghPath}/git/trees/#{commit.id}", defer err, tree
			unless rootTree.any((x) -> x.path is ".deploy")
				ret += "#{commit.id}: Could not find file `.deploy`.\n"
				continue
			await request
				uri: "#{ghPath}/git/blobs/#{rootTree.first((x) -> x.path is ".deploy").sha}"
				encoding: "utf-8",
				defer err, dF
			deployFile = dF.content.lines (line) ->
				a = line.split(":").select((x) -> do x.words)
				app:
					name:		a[0][1]
					provider:	a[0][0]
				trigger:
					type:		a[1][0]
					target:		a[1][1]
			await request "#{ghPath}/branches", defer err, branches
			for target in deployFile
				unless do target.app.provider.toLowerCase is "heroku"
					ret += "#{commit.id}/.deploy: #{target.app.provider} targets are currently not supported.\n"
					continue
				await request "https://:#{process.env.DEPLOY_API_KEY}@api.heroku.com/apps/#{target.app.name}/config_vars", defer err, data
				log "An unknown error occured while authenticating." if err
				
				if target.trigger.type is "branch"
					if branches.any ((x) -> x.name is target.trigger.target and x.commit.sha is commit.id)
						dTS = doTheStuff "git@heroku.com:#{target.app.name}.git", "#{ghPath}/git/trees/#{commit.id}"
						ret +=
							if dTS.success
								"#{commit.id}: Could not deploy commit. Details...\n#{dTS.message}\n"
							else
								"#{commit.id}: Deployed commit.\n"
				else if target.trigger.type is "hashtag"
					if (do commit.message.getHashtags).contains target.trigger.target
						dTS = doTheStuff "git@heroku.com:#{target.app.name}.git", "#{ghPath}/git/trees/#{commit.id}"
						ret +=
							if dTS.success
								"#{commit.id}: Could not deploy commit. Details...\n#{dTS.message}\n"
							else
								"#{commit.id}: Deployed commit.\n"
			break
		
# Start Server
server.listen (port = process.env.PORT || 5000), -> console.log "Listening on #{port}"