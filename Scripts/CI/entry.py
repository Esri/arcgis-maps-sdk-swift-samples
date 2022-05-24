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

import os
import json
import argparse
import subprocess as sp
from typing import List


def run_mdl(readme_path: str) -> int:
    print("**** mdl ****")
    code = sp.call(f'mdl --style /style.rb "{readme_path}"', shell=True)
    return code


def run_style_check(dirname: str) -> int:
    print("**** README checker ****")
    code0 = sp.call(f'python3 /readme_checker.py -s "{dirname}"', shell=True)
    print("**** Metadata checker ****")
    code1 = sp.call(f'python3 /metadata_checker.py -s "{dirname}"', shell=True)
    return code0 + code1


def read_json(filenames_json_data) -> List[str]:
    return [filename for filename in filenames_json_data]


def main():
    msg = 'Entry point of the docker to run mdl and style check scripts.'
    parser = argparse.ArgumentParser(description=msg)
    parser.add_argument('-s', '--string', help='A JSON array of file paths.')
    args = parser.parse_args()
    files = None

    print("** Starting checks **")
    if args.string:
        files = read_json(json.loads(args.string))
        if not files:
            print('Invalid input file paths string, abort.')
            exit(1)
    else:
        print('Invalid arguments, abort.')
        exit(1)

    return_code = 0
    # A set of dirname strings to avoid duplicate checks on the same sample.
    samples_set = set()

    for f in files:
        if not os.path.exists(f):
            # The changed file is deleted, no need to style check.
            continue

        path_parts = os.path.normpath(f).split(os.path.sep)

        if len(path_parts) < 4:
            # e.g., ./Shared/Samples/{sample_name}/README.md
            # A file not in samples folder, omit.
            # E.g. might be in the root folder or other unrelated folders.
            continue

        # Get filename and folder name of the changed sample.
        filename = os.path.basename(f)
        dir_path = os.path.dirname(f)
        l_name = filename.lower()
        l_readme = 'readme.md'
        l_metadata = 'readme.metadata.json'

        # Changed file is not a README or metadata file, ignore.
        if l_name not in [l_readme, l_metadata]:
            continue

        # Print debug information for current sample.
        if dir_path not in samples_set:
            print(f'*** Checking {dir_path} ***')

        # Check if the capitalization of doc filenames are correct.
        if l_name == l_readme and filename != 'README.md':
            print(f'Error: {dir_path} README has wrong capitalization')
            return_code += 1

        if l_name == l_metadata and filename != 'README.metadata.json':
            print(f'Error: {dir_path} metadata has wrong capitalization')
            return_code += 1

        # Run markdownlint on README file.
        if filename == 'README.md':
            return_code += run_mdl(f)

        # Run the other Python checks on the whole sample folder.
        if dir_path not in samples_set:
            samples_set.add(dir_path)
            return_code += run_style_check(dir_path)

    if return_code != 0:
        # Non-zero code occurred during the process.
        exit(return_code)
    else:
        exit(0)


if __name__ == '__main__':
    main()
