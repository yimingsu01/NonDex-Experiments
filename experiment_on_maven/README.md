# Maven Project Slug Finder and ID Flaky Test Detector

This folder provides tools to identify Maven projects on GitHub and analyze them for ID flaky tests.

## Prerequisites
- Python 3.x
- GitHub Account and Personal Access Token
- Maven

## Usage

### Step 1: Find Recent Popular Repositories

Use the `find-recent-popular-repos.py` script to search for Maven project slugs based on star count and creation date.

```bash
python3 find-recent-popular-repos.py ${github_username} ${github_token} ${min_stars} ${max_stars}, ${earliest_created}, ${latest_created}, ${page}
```

- **`${github_username}`**: Your GitHub username.
- **`${github_token}`**: Your GitHub Personal Access Token.
- **`${min_stars}`**: Minimum number of stars the repository should have.
- **`${max_stars}`**: Maximum number of stars the repository should have.
- **`${earliest_created}`**: The earliest creation date of the repositories (format: `YYYY-MM-DD`).
- **`${latest_created}`**: The latest creation date of the repositories (format: `YYYY-MM-DD`).
- **`${page}`**: Page number of the GitHub API results to fetch.

This command will generate a `repos.txt` file containing the slugs of candidate Maven projects.

### Step 2: Identify ID Flaky Tests

Run the `run-nondex-multiple-projects.sh` script to analyze the repositories listed in `repos.txt` and identify ID flaky tests.

```bash
./runNonDexMultipleProjects.sh repos.txt
```

- **`result.csv`**: This file will contain the general results of the experiment.
- **`flaky.csv`**: This file will contain information on possible ID flaky tests.

### Sample Data

The `result` folder in this repository contains data from a sample run of the above steps.
