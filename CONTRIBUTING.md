# Contributing to DeclareSchema

This document explains our guidelines and workflows to contributing to an Invoca open source project.  Please take care to follow the guidelines, as they exist to help us manage changes in a timely and efficient manner.

## Code of Conduct
All contributors to this project must adhere to the [Community Code of Conduct](CODE-OF-CONDUCT.md)

## Environment Setup
1. Install `docker` and ensure that the daemon is running
2. Open the project inside the specified [devcontainer](https://github.com/devcontainers) configured in `.devcontainer/devcontainer.json`

## Branching

* __Create an issue before starting a branch__
* For bugs, prefix the branch name with `bug/`
* For features, prefix the branch name with `feature/`
* Include the issue number and a short description of the issue

Examples
* `bug/1234_fix_issue_with_postgresql_adapter`
* `feature/4321_add_explicit_postgresql_adapter_support`

## Filing Issues

* Use the appropriate template provided
* Include as much information as possible to help:
  * The person who will be fixing the bug understand the issue
  * The person code reviewing the fix to understand what the original need was
* Check for open issues before filing your own

## Committing

* Break your commits into logical atomic units. Well-segmented commits make it much easier for others to step through your changes.
* Limit your subject (first) line to 50 characters (GitHub truncates more than 70).
* Provide a body if you'd like to explain your commit in detail.
* Capitalize the beginning of your subject line, and do not end the subject line with a period.
* Your subject line should complete this sentence: `If applied, this commit will [your subject line]`.
* Don't use [magic GitHub words](https://help.github.com/articles/closing-issues-using-keywords/) in your commits to close issues - do that in the pull request for your code instead.
* Adapted from [How to Write a Git Commit Message](https://chris.beams.io/posts/git-commit/#seven-rules).

## Making Pull Requests

* Use fill out the template provided
* Provide a link to the issue being resolved by the PR
* Make sure to include tests
* Resolve linting comments from Hound before requesting review
