# Load Modules
express	= require "express"
crypto	= require "crypto"
http	= require "http"
fs		= require "fs"
coffee	= require "coffee"
Sync	= require "sync"
fluent	= require "./fluent"
request	= require "request"
md5		= require "MD5"

# Helper Methods
String::getHashtags -> @match /(#[A-Za-z0-9-_]+)/g

doTheStuff = (targetRepo, rootTreeURL) ->
	downloadRepo = (repo, folder) ->
		return; # git clone...
	recSrc = (treeUrl, folder) ->
		tree = request.sync(null, treeUrl).tree
		tree.forEach (node) ->
			if node.type is "tree"
				nf = "#{folder}/#{node.path}"
				fs.mkdir.sync null, nf, "0777"
				recSrc node.url, nf
			else if node.type is "blob"
				fs.writeFile.sync null, "#{folder}/#{node.path}", new Buffer(node.content, node.encoding)
	
	folder = md5 rootTree + do (new Date).getTime

# Setup Server
server = do express.createServer
server.configure ->
	server.use do express.logger
	server.use do express.cookieParser
	server.use express.session secret: process.env.SSO_SALT
	server.use do express.bodyParser
	server.use -> Sync -> do arguments[2]

# Receive Post Requests – GitHub
server.post "/github", (req, res, next) ->
	func ->
		payload = req.body.payload
		return "Private repositories are currently not supported.\n" if payload.repository.private
		ghPath = "https://api.github.com/repos/#{payload.repository.owner.name}/#{payload.repository.name}"
		ret = ""
		for commit in payload.commits # Bad Code: Need to first sort by datestamps in descending order.
			rootTree = request.sync(null, "#{ghPath}/git/trees/#{commit.id}").tree
			unless rootTree.any((x) -> x.path is ".deploy")
				ret += "#{commit.id}: Could not find file `.deploy`.\n"
				continue
			deployFile = request.sync(null, "#{ghPath}/git/blobs/#{rootTree.first((x) -> x.path is ".deploy").sha}", encoding: "utf-8")
				.content.split("\r\n").selectMany((x) -> x.split "\r").selectMany((x) -> x.split "\n").where((x) -> x isnt "")
				.select (line) ->
					a = line.split(":").select((x) -> x.split(" ").where (y) -> y isnt "")
					app:
						name:		a[0][1]
						provider:	a[0][0]
					trigger:
						verb:		a[1][0]
						noun:		a[1][1]
			branches = request.sync(null, "#{ghPath}/branches")
			for target in deployFile
				unless do target.app.provider.toLowerCase is "heroku"
					ret += "#{commit.id}/.deploy: #{target.app.provider} targets are currently not supported.\n"
					continue
				if target.trigger.verb is "branch"
					if branches.any ((x) -> x.name is target.trigger.noun and x.commit.sha is commit.id)
						ret += doTheStuff "git@heroku.com:#{target.app.name}", "#{ghPath}/git/trees/#{commit.id}"
				else if target.trigger.verb is "hashtag"
					if (do commit.message.getHashtags).contains target.trigger.noun
						ret += doTheStuff "git@heroku.com:#{target.app.name}", "#{ghPath}/git/trees/#{commit.id}"
			break
	do func

# Start Server
server.listen (port = process.env.PORT || 5000), -> console.log "Listening on #{port}"