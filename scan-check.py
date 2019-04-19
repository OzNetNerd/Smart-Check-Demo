import requests
import urllib3
import json
import argparse

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class SmartCheck:
    def __init__(self, username, password, base_url):
        self.base_url = base_url
        self.token = self._create_session(username, password)

    def _create_session(self, username, password):
        payload = {
            'user': {
                'userID': username,
                'password': password,
            }
        }

        output_json = self._api_call('POST', 'api/sessions', payload, auth=False)
        token = output_json['token']
        print(token)
        return token

    def _api_call(self, verb, endpoint, payload, auth=True):
        headers = {
            'Content-type': 'application/json',
        }

        if auth:
            headers['Authorization'] = f'Bearer {self.token}'

        path = f'{self.base_url}/{endpoint}'
        call_verb = getattr(requests, verb.lower())
        request_output = call_verb(path, headers=headers, json=payload, verify=False)

        output_json = request_output.json()
        return output_json

    def list_sessions(self):
        output = self._api_call('get', 'api/sessions', payload='')
        print(json.dumps(output, indent=4, sort_keys=True))


def get_args():
    parser = argparse.ArgumentParser(description='Smart Check API Wrapper')
    parser.add_argument('-u', '--username', help='Smart Check username', required=True)
    parser.add_argument('-p', '--password', help='Smart Check password', required=True)
    parser.add_argument('-b', '--base-url', dest='base_url', help='Smart Check URL', required=True)
    args = parser.parse_args()

    return args


def main():
    args = get_args()
    sc = SmartCheck(args.username, args.password, args.base_url)
    sc.list_sessions()


if __name__ == '__main__':
    main()
