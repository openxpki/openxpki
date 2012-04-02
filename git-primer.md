Git and OpenXPK ... a short primer for people new to git
========================================================

Introduction
------------

Some background info first, then onto the command line. OpenXPKI is based on UNIX so familiarity with the shell (korn, bash, ...) and SSH is expected.

Authoritative repository
------------------------

https://github.com/openxpki/openxpki

Register (for free) at github.com and follow this project. The website will provide the URLs needed to perform a git clone (see below).

Development model
-----------------

Git does not force you to do things in a certain way. That's good because you can do things your own way. It's also bad because if different contributors use different approaches there will be chaos. 

There are two official branches:

master    The stable, production branch containing officially-released versions
develop   The unstable, development branch that may or may not work

Additional branches may be created by integrators (see below for a definition of what an integrator is). 

If you want the code for the latest (or any) release: checkout the master branch.

If you want to do the latest development build: checkout the develop branch.

For some philosophical insight into the branching and naming philosophy used here please see git-flow (https://github.com/nvie/gitflow)

Roles
-----

Note: any person can have more than one role, i.e. act as both an integrator and developer.

- Integrator:
	An integrator's job is to take code provided by developers and integrate it into other branches. In this role (s)he does not write any code but simply puts things together. Integrators have write access to the authoritative repository.

- Developer:
	Writes/changes code and pass them on to the integrators. They do not need access to the authoritative repository.


Before we get started
---------------------


Workflow for followers
----------------------

If you just want to follow the project (e.g. to do stable and development builds) you can pull directly from the authoritative repository.

	git clone git://github.com/openxpki/openxpki.git

To follow the official releases, do

	git checkout master

and then

	git pull

whenever you want to update your local copy.

To follow the (unstable) development (e.g. for your nightly builds), do

	git checkout develop

and then

	git pull

whenever you want to update your local copy.



Workflow for developers
-----------------------

Note: There is more than one way to do it. This describes the workflow based on GitHub's pull request feature. Using this feature is not a requirement, so if you're familiar with git feel free to do it your own way.

First, you need to create your own repository on GitHub.

- Login to GitHub. 
- Go to https://github.com/openxpki/openxpki and click on "Fork" on the upper right hand side. This will create your own, public repository based on the official one. Click on "Fork to <your username>". 

Next, you need your own local copy of that repository.

	git clone git@github.com:<username>/openxpki.git
	cd openxpki (the newly created directory containing your copy)

Work is performed in your own, private branches, which are based on the develop branch. An integrator will integrate your work into the develop branch later after you've finished your piece of work.

- Switch to the development branch: 

	git checkout develop

- Important: create your own branch, e.g. "feature/git-primer"

	git branch feature/git-primer

- Important: switch to your new branch: 

	git checkout feature/git-primer

- Important: push your new branch to your own GitHub repository

	git push origin feature/git-primer

Code ... (or write documentation ... or both).

After completing a meaningful piece of work you may want to commit your changes to your private branch.

- To remove files, use git rm file(s).
- To add new files in the next commit, use git add file(s).
- To stage modified files for the next commit, use git add file(s).

Files you have created or modified but not staged using "git add" will not be committed. Now use

	git commit

to commit the staged changes. The format of the log message should be:

- One line containing a brief summary of the commit.
- A blank line.
- Further explanations of the commit if necessary.

Whenever you want others to see the work you are doing in your own branch you can push your commits to your own GitHub repo using

	git push 

Your work is happening on a separate branch, so it is not affected by any commits to the master or develop branch. Hence it is safe to do regular

	git pull

requests to stay in sync with the upstream repo.

Let's say you created your own feature branch when the develop branch was as commit b and you created your first commit x:

	develop              a - b   
	                         \
	feature/git-primer         - x

Now someone else's changes may get added to develop and your changes are no longer based on the latest commit of the develop branch:

	develop              a - b - c - d
	                         \
	feature/git-primer         - x

This may or may not create problems when integrating your changes into the develop branch. To facilitate integration, you should make sure that your changes are based on the latest commit of the develop branch before sending a pull request. This is done by rebasing your commits (sometimes also referred to as rewriting history).

If your work does not conflict with the changes in develop (i.e. you haven't changed the same lines) the command 

	git rebase develop feature/git-primer

will result in a new graph like this:

	develop              a - b - c - d
	                                 \
	feature/git-primer                 - x'

Note: if "git rebase" does result in conflicts you will need to resolve these before you can proceed. Ask your friendly git guru for help if necessary. :-)

Note: if you have "git push"-ed your previous commits to your GitHub repository your local copy and the one on GitHub will have diverged. To fix that, you will need to 

	git push -f

once to force your local changes into (your own) GitHub repo.

Let's say you complete your work with one final commit

	develop              a - b - c - d
	                                 \
	feature/git-primer                 - x' - y

and pushed everything to GitHub. You can now ask an integrator to pull your changes into the develop branch.

To do that, log on to GtHub and visit your own openxpki repo fork. 

- Click on the branches tab.
- Click on your branch that you want merged upstream.
- Click on "Pull Request" in the upper right hand corner.

IMPORTANT: make sure you adjust the settings on the following screen. By default, it will suggest merging into the master branch. Change this to the develop branch and click on "Update commit range". 

Click on "Send pull request".

A few final notes:

- You can have (and work on) as many private branches as you like.
- For different features or bug fixes create different branches.
- If in doubt, branch. You can easily merge later. Splitting up commits is much more difficult.


Workflow for integrators
------------------------

The job of an integrator is to act as a gatekeeper and quality assurance for changes to the project. When a developer sends a merge request all integrators will recieve a message. One of them will review the changes and either

- accept the changes and merge the pull request or
- write comments and ask for further information and/or changes or
- decline and close the pull request without merging.

Note: the integrator may be the same person as the developer that sent the pull request.

To act on pull requests simply log on to GitHub and click on the pull request in your "Public Activity" timeline. If you can't find it there look at your notifications (the little radio tower at the top right). The web form is pretty self-explanatory. 


Famous last words
-----------------

If you feel something is incorrect or missing in the guide ... please fork, branch, push and send a pull request. Thank you! :-)


