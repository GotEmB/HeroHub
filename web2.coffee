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

cloneRepo = (repoURL, folder) ->
	stderr = ""
	git = child_p.spawn "git", ["clone", repo, folder]
	git.stderr.on (data) -> stderr += data
	await git.exit.on defer exitcode
	if stderr.indexOf("fatal") isnt -1
		success:	false
		message:	stderr
	else
		success:	true



# Receive Post Requests – GitHub
server.post "/github/:ss-key", (req, res, next) ->
	updateFolder = (ghPath, commit, folder) ->
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
	func = ->
		payload = req.body.payload
		return "Private repositories are currently not supported." if payload.repository.private
		ghPath = "https://api.github.com/repos/#{payload.repository.owner.name}/#{payload.repository.name}"