#!/bin/bash 

# when testing this locally, you'll have to first set the following environment variables in your bash session:
    # export GH_API_TOKEN=(your personal github token)
    # export PR_REF=(the PR source branch name)
    # export PR_NUMBER=(the PR number)

# loop through each of the workflow statuses that are believed to be possible at this point, and collect all of the matches.  This is difficult to know what exact statuses to look at since the GitHub Actions documentation
# doesn't actually explain what these mean, so this is an educated guess based on just the status names.  See list at https://docs.github.com/en/rest/actions/workflow-runs?apiVersion=2022-11-28
possibleWorkflowStatuses=("queued", "waiting", "pending", "requested", "in_progress")
allMatchingRuns="[]"

for workflowStatus in "${possibleWorkflowStatuses[@]}" ; do
    thisStatusResponse=$(curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_API_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/repos/CardFlight/test-instance/actions/runs?event=repository_dispatch&status=$workflowStatus")
    runsMatchingThisStatus=$(echo $thisStatusResponse | jq .workflow_runs)
    runsMatchingThisStatusCount=$(echo $thisStatusResponse | jq .total_count)
    echo "DEBUG: for status $workflowStatus found $runsMatchingThisStatusCount matches."

    allMatchingRuns=$(jq -n --argjson list1 "$allMatchingRuns" --argjson list2 "$runsMatchingThisStatus" '$list1 + $list2')
    allMatchingRunsCount=$(($allMatchingRunsCount + $runsMatchingThisStatusCount))
    echo "DEBUG: now have a grand total of $allMatchingRunsCount matches."
done

echo "Found $allMatchingRunsCount workflow runs matching the expected statuses."

echo "DEBUG: allMatchingRuns: $allMatchingRuns"

if [[ $allMatchingRunsCount -eq 0 ]]
then
    echo "Did not find any runs of the workflow that creates on-demand environments which matched the expected statuses."
    exit 1
fi


# out of the total workflow runs matching the statuses, find the run(s) matching this PR.
# Do this by matching name, since the workflow that creates OD envs names each workflow run based on the PR number given to it.
allRunsMatchingThisPr=$(echo $allMatchingRuns | jq -r --arg PR_NAME "create env pr$PR_NUMBER" '[.[] | select(.name == $PR_NAME)] | unique_by(.id)')
allRunsMatchingThisPrCount=$(echo $allRunsMatchingThisPr | jq length)
echo "Found $allRunsMatchingThisPrCount workflow runs matching this PR."
if [[ $allRunsMatchingThisPrCount -eq 0 ]]
then
    echo "Did not find any runs of the workflow that creates on-demand environments which matched this PR."
    exit 1
fi


# It is possible there are multiple matching runs for this PR from previous e2e test runs.  (For example, this happens if someone opens a PR and then soon thereafter pushes
# a commit to the same branch, which would result in one run triggered by the PR being opened and another by the "syncrhonize" trigger.) In this case several things are necessary:
# 1) identify the most recent run
createEnvWorkflowRunId=$(echo $allRunsMatchingThisPr | jq 'max_by(.created_at)' | jq .id)
echo "Latest workflow run ID is: $createEnvWorkflowRunId"

# 2) cancel those that are not the most recent.  Otherwise the second on-demand environment will overwrite the first, which could cause tests to fail due to the env changing during runtime.
if [[ $allRunsMatchingThisPrCount -gt 1 ]]
then
    echo "Found multiple matching workflows for this PR, so will cancel all those that are not the most recent."
    runsToCancel=$(echo $allRunsMatchingThisPr | jq -r --argjson LATEST "$createEnvWorkflowRunId" '[.[] | select(.id != $LATEST)]' | jq '[.[].id]')
    echo "Will cancel runs with these IDs:"
    echo $runsToCancel

    for runId in $(jq -r '.[]' <<< "$runsToCancel") ; do
        echo "About to cancel run $runId"
        cancelResponse=$(curl -L --write-out "%{http_code}" --silent --output /dev/null \
            -X POST \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer $GH_API_TOKEN" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "https://api.github.com/repos/CardFlight/test-instance/actions/runs/$runId/cancel")

        if [[ $createEnvResponse -ne "202" ]];
        then
            echo "WARNING: Got response $cancelResponse back from attempting to cancel an outdated on-demand env creation workflow run.  This may cause problems later on."
        fi
    done
fi


# poll the github api to see when this workflow run reaches the completed state
# Note that while this is an infinite loop in this script, there are timeouts in the workflow so that it can't run forever in that context.
while true; do
    getWorkflowResponse=$(curl -L -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_API_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "https://api.github.com/repos/CardFlight/test-instance/actions/runs/$createEnvWorkflowRunId")
    workflowStatus=$(echo $getWorkflowResponse | jq -r .status)
    echo "Workflow status is currently: $workflowStatus"

    case $workflowStatus in
        "in_progress" | "queued")
            sleep 30   # throttle how often it polls
            ;;
        *)
            break
    esac
done

if [[ "$workflowStatus" != "completed" ]]
then
    echo "Workflow in unexpected state '$workflowStatus'. Exiting as failed."
    exit 1
fi

workflowConclusion=$(echo $getWorkflowResponse | jq -r .conclusion)
if [[ "$workflowConclusion" != "success" ]]
then
    echo "Workflow conclusion was '$workflowConclusion'. Exiting as failed."
    exit 1
fi


echo "On-demand environment deployment was successful."
exit 0
