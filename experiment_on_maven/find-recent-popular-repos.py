import sys
import requests

def get_repositories(github_username, github_token, min_stars, max_stars, earliest_created, latest_created, page):
    headers = {
        'Authorization': f'token {github_token}',
        'Accept': 'application/vnd.github.v3+json',
    }
    
    query = (
        f'language:java stars:{min_stars}..{max_stars} '
        f'created:{earliest_created}..{latest_created}'
    )
    
    url = f'https://api.github.com/search/repositories?q={query}&page={page}&per_page=100'
    
    response = requests.get(url, headers=headers)
    
    if response.status_code != 200:
        print(f'Error: {response.status_code}')
        print(response.json())
        sys.exit(1)
    
    data = response.json()
    repos = data.get('items', [])
    
    maven_repos = []
    
    for repo in repos:
        repo_full_name = repo['full_name']
        repo_url = f'https://api.github.com/repos/{repo_full_name}/contents'
        repo_response = requests.get(repo_url, headers=headers)
        
        if repo_response.status_code == 200:
            repo_contents = repo_response.json()
            has_pom_xml = any(file.get('name') == 'pom.xml' for file in repo_contents)
            if has_pom_xml:
                maven_repos.append(repo_full_name)
        else:
            print(f'Error accessing repo contents: {repo_response.status_code} for {repo_full_name}')
    
    return maven_repos

def main():
    if len(sys.argv) != 8:
        print("Usage: python3 find-recent-popular-repos.py <github_username> <github_token> <min_stars> <max_stars> <earliest_created> <latest_created> <page>")
        sys.exit(1)

    github_username = sys.argv[1]
    github_token = sys.argv[2]
    min_stars = sys.argv[3]
    max_stars = sys.argv[4]
    earliest_created = sys.argv[5]
    latest_created = sys.argv[6]
    page = int(sys.argv[7])
    
    repo_slugs = get_repositories(github_username, github_token, min_stars, max_stars, earliest_created, latest_created, page)
    
    with open('repos.txt', 'w') as f:
        for slug in repo_slugs:
            f.write(f'{slug}\n')
    
    print(f'Found {len(repo_slugs)} Maven repositories. Results saved to repos.txt')

if __name__ == '__main__':
    main()
