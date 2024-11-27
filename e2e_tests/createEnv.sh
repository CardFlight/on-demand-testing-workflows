#!/bin/bash 

# when testing this locally, you'll have to first set the following environment variables in your bash session:
    # export GH_API_TOKEN=(your personal github token)
    # export BRANCH_KEY=(the key used by test-instance to set the branch of the project in PR)
    # export PR_REF=(the PR source branch name)
    # export PR_NUMBER=(the PR number)

createEnvResponse=$(curl -L --write-out "%{http_code}" --silent --output /dev/null -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_API_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/CardFlight/test-instance/dispatches -d "{\"event_type\": \"create-on-demand-env\", \"client_payload\": {\"$BRANCH_KEY\": \"$PR_REF\", \"uniqueEnvName\": \"pr$PR_NUMBER\"}}")

if [[ $createEnvResponse -ne "204" ]];
then
    echo "Got response $createEnvResponse back from attempting to trigger creation of the on-demand environment."
    exit 1
fi

echo "Triggering creation of on-demand environment was successful."
exit 0
