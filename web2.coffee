# Load Modules
express	= require "express"
crypto	= require "crypto"
http	= require "http"
fs		= require "fs"
coffee	= require "coffee"
fluent	= require "./fluent"
request	= require "request"
md5		= require "MD5"
moment	= require "moment"

# Helper Methods
String::getHashtags -> @match /(#[A-Za-z0-9-_]+)/g

log = (message) ->
	@prototype.msg = "" unless @prototype.msg
	@prototype.msg +=  do (new Date).toUTCString + ": #{message}"

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

pushRepo = (repo, folder, commit) ->
	stderr = ""
	git = child_p.spawn "git", ["add", "."]
	git.stderr.on (data) -> stderr += data
	await git.exit.on defer exitcode
	git = child_p.spawn "git", ["commit", "-m", "Building commit #{commit}."]
	git.stderr.on (data) -> stderr += data
	await git.exit.on defer exitcode
	if stderr.indexOf("fatal") isnt -1
		success:	false
		message:	stderr
	else
		success:	true

parseDeployString = (deployString) ->
	dF.content.lines (line) ->
		a = line.split(":").select((x) -> do x.words)
		app:
			name:		a[0][1]
			provider:	a[0][0]
		trigger:
			type:		a[1][0]
			target:		a[1][1]

updateFolderFromGitHub = (ghPath, commit, folder) ->
	recSrc = (treeUrl, folder) ->
		await request treeUrl, defer err, tree
		tree.forEach (node) ->
			if node.type is "tree"
				nf = "#{folder}/#{node.path}"
				await fs.mkdir nf, "0777", defer err
				recSrc node.url, nf
			else if node.type is "blob"
				await fs.writeFile "#{folder}/#{node.path}", new Buffer(node.content, node.encoding), defer err
	recSrc "#{ghPath}/git/trees/#{commit.id}", folder

doItGitHub = (ghPath, commit, targetApp, targetProvider) ->	
	folder = "sandbox/" + md5 rootTree + do (new Date).getTime
	targetRepo = getAppGit targetApp, targetProvider
	cR = cloneRepo targetRepo, folder
	return cR unless cR.success
	updateFolderFromGitHub ghPath, commit, folder
	pushRepo targetRepo, folder, commit

processGitHub = (payload) ->
	return "Private repositories are currently not supported." if payload.repository.private
	ghPath = "https://api.github.com/repos/#{payload.repository.owner.name}/#{payload.repository.name}"
	return "Private repositories are currently not supported." if payload.repository.private
	ghPath = "https://api.github.com/repos/#{payload.repository.owner.name}/#{payload.repository.name}"
	payload.commits = payload.commits.orderByDesc (x) -> moment x.timestamp
	doneTriggers =
		branches: []
		hashtags: []
	payload.commits.forEach (commit) ->
		await request "#{ghPath}/git/trees/#{commit.id}", defer err, tree
		unless rootTree.any((x) -> x.path is ".deploy")
			ret += "#{commit.id}: Could not find file `.deploy`.\n"
			return
		await request
			uri: "#{ghPath}/git/blobs/#{rootTree.first((x) -> x.path is ".deploy").sha}"
			encoding: "utf-8",
			defer err, dF
		deployFile = parseDeployString dF
		await request "#{ghPath}/branches", defer err, branches
		deployFile.forEach (target) ->
			return "#{commit.id}/.deploy: #{target.app.provider} targets are currently not supported.\n" if do target.app.provider.toLowerCase isnt "heroku"
			runDoIt = ->
				dTS = doItGitHub ghPath, commit, target.app.name, target.app.provider
				log "#{commit.id}: #{if dTS.success then "Could not deploy commit. Details...\n#{dTS.message}" else "Deployed commit"}\n"
				dTS.success
			if target.trigger.type is "branch"
				if branches.any ((x) -> x.name is target.trigger.target and x.commit.sha is commit.id and not doneTriggers.branches.contains x.name)
					doneTriggers.branches.push target.trigger.target if do runDoIt
			else if target.trigger.type is "hashtag"
				if (do commit.message.getHashtags).except(doneTriggers.hashtags).contains target.trigger.target
					doneTriggers.hashtags.push target.trigger.target if do runDoIt

# Setup Server
server = do express.createServer
server.configure ->
	server.use do express.logger
	server.use do express.bodyParser
	
server.post "/deploy", (req, res, next) ->
	return; #...

# Start Server
server.listen (port = process.env.PORT || 5000), -> console.log "Listening on #{port}"