# on-demand-testing-workflows

On-Demand environment workflows for e2e testing, shareable as a Git submodule.

Documentation on Git submodules: https://git-scm.com/book/en/v2/Git-Tools-Submodules

## First-time setup

- Navigate to your project's `.github/workflows` folder in a terminal window.
- Execute `git submodule add git@github.com:CardFlight/on-demand-testing-workflows.git`. You should see a new folder at `.github/workflows/on-demand-testing-workflows/`.
- Copy the file `.github/workflows/on-demand-testing-workflows/e2e_tests.template.yml` to `.github/workflows/e2e_tests.yml`.
- Search for the phrase **EDIT ME** in the new file and update it to match your project and e2e tests.
- Create a new GitHub action in your project repo, pointing to `.github/workflows/e2e_tests.yml`.

## Cloning

- When you clone a project that includes Git submodules, you should pass the `--recurse-submodules` flag to the `git clone` command.
  - If you forget to do this, you can also navigate to the submodule folder and call `git submodule init && git submodule update`.

## Pulling updates

Either of the following will work:

- Navigate to the submodule and run `git pull`.
- From outside the submodule, run `git submodule update --remote on-demand-testing-workflows`.

## Tips

- A submodule is just a Git repository! You can clone and commit to it like any other repo.
- It's easiest to treat the submodule like a Gem or NPM library and leave its files alone. You'll be able to get updates without dealing with merge conflicts. Any files you want to change or add should be copied out.
- However, you _can_ edit the submodule's files directly. There's little danger of accidentally pushing those changes upstream.