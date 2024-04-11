#!/usr/bin/env python3
# Copyright 2022 Esri
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
from difflib import unified_diff
from common import *


def run_check(path: str) -> None:
    """
    Creates a sample's metadata by running the script against its path, and
    write to a separate json for comparison.

    The path may look like
    /Shared/Samples/Display a map/
    """
    checker = Metadata(path)
    # 1. Populate from README.
    try:
        checker.populate_from_readme()
        checker.populate_from_paths()
    except Exception as err:
        print(f'Error populate failed for - {checker.folder_name}.')
        raise err

    json_path = os.path.join(path, 'README.metadata.json')
    # 2. Load JSON.
    try:
        json_file = open(json_path, 'r')
        json_data = json.load(json_file)
    except Exception as err:
        print(f'Error reading JSON - {path} - {err}')
        raise err
    else:
        json_file.close()

    # The special rule not to compare the category, since 200.0.
    checker.category = json_data['category']

    # The special rule not to compare the redirect_from.
    checker.redirect_from = json_data['redirect_from']

    # The special rule not to compare offline_data.
    if 'offline_data' in json_data:
        checker.offline_data = json_data['offline_data']

    # The special rule to be lenient on shortened description.
    # If the original json has a shortened/special char purged description,
    # then no need to raise an error.
    if json_data['description'] in sub_special_char(checker.description):
        checker.description = json_data['description']

    # The special rule to ignore the order of src filenames.
    # If the original json has all the filenames, then it is good.
    # Note: since SwiftUI View code generation depends on the order of snippets,
    # the wrong order can be spotted when the sample is run.
    if sorted(json_data['snippets']) == checker.snippets:
        checker.snippets = json_data['snippets']

    # 3. Compare schema-based generated JSON to the source JSON.
    new = checker.flush_to_json_string()
    original = json.dumps(json_data, indent=4, sort_keys=True)
    if new != original:
        expected = new.splitlines()
        actual = original.splitlines()
        diff = '\n'.join(unified_diff(expected, actual))
        raise Exception(f'Error inconsistent metadata - {path} - {diff}')

    # 4. Check category.
    try:
        checker.check_category()
    except Exception as err:
        raise Exception(f'{checker.folder_path} - {err}')


def all_samples(path: str):
    """
    Run the check on all samples.

    :param path: The path to 'arcgis-ios-sdk-samples' folder.
    :return: None. Throws if exception occurs.
    """
    exception_count = 0
    for root, dirs, files in os.walk(path):
        # Get parent folder name.
        parent_folder_name = get_folder_name_from_path(root)
        if parent_folder_name == "Samples":
            for dir_name in dirs:
                # /Shared/Samples/{sample_name}/
                sample_path = os.path.join(root, dir_name)
                # Omit empty folders - they are omitted by Git.
                if len([f for f in os.listdir(sample_path)
                        if not f.startswith('.DS_Store')]) == 0:
                    continue
                try:
                    run_check(sample_path)
                except Exception as err:
                    exception_count += 1
                    print(f'{exception_count}. {err}')

    # Throw once if there are exceptions.
    if exception_count > 0:
        raise Exception('Error(s) occurred during checking all samples.')


def main():
    # Initialize parser.
    msg = 'Metadata checker. Run it against the arcgis-maps-sdk-swift-samples ' \
          'folder or a single sample folder. ' \
          'On success: Script will exit with zero. ' \
          'On failure: Style violations will print to console and the script ' \
          'will exit with non-zero code.'
    parser = argparse.ArgumentParser(description=msg)
    parser.add_argument('-a', '--all', help='path to project root folder')
    parser.add_argument('-s', '--single', help='path to a single sample')
    args = parser.parse_args()
    if args.all:
        try:
            all_samples(args.all)
        except Exception as err:
            raise err
    elif args.single:
        try:
            run_check(args.single)
        except Exception as err:
            raise err
    else:
        raise Exception('Invalid arguments, abort.')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'{error}')
        exit(1)
