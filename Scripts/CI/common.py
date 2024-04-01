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
import re
import json
from typing import List, Set


# region Global Sets
# A set of words that get omitted during letter-case checks.
# This set will be updated when a special word appears in a new sample.
exception_proper_nouns = {
    'Arcade',
    'ArcGIS Online',
    'ArcGIS Pro',
    'GeoPackage',
    'OAuth',
    'OpenStreetMap',
    'SwiftUI',
    'Web Mercator'
}

# A set of category folder names.
categories = {
    'Analysis',
    'Augmented Reality',
    'Cloud and Portal',
    'Edit and Manage Data',
    'Layers',
    'Maps',
    'Scenes',
    'Routing and Logistics',
    'Search and Query',
    'Utility Networks',
    'Visualization'
}
# endregion


# region Static Functions
def sub_special_char(string: str) -> str:
    """
    Replace if a string contains special characters.

    :param string: The input string.
    :return: A new string without special characters.
    """
    regex = re.compile(r'[@_!#$%^&*<>?|/\\}{~:]')
    return re.sub(regex, '', string)


def parse_head(head_string: str) -> (str, str):
    """
    Parse the `Title` section of README file and get the title and description.

    :param head_string: A string containing title, description and images.
    :return: Stripped title and description strings.
    """
    # Split title section and rule out empty lines.
    parts = list(filter(bool, head_string.splitlines()))
    if len(parts) < 3:
        raise Exception('README description parse failure!')
    title = parts[0].lstrip('# ').rstrip()
    description = parts[1].strip()
    return title, description


def parse_apis(apis_string: str) -> List[str]:
    """
    Parse the `Relevant API` section and get a list of APIs.

    :param apis_string: A string containing all APIs.
    :return: A sorted list of stripped API names.
    """
    apis = list(filter(bool, apis_string.splitlines()))
    if not apis:
        raise Exception('README Relevant API parse failure!')
    return sorted([api.lstrip('*- ').rstrip() for api in apis])


def parse_tags(tags_string: str) -> List[str]:
    """
    Parse the `Tags` section and get a list of tags.

    :param tags_string: A string containing all tags, with comma as delimiter.
    :return: A sorted list of stripped tags.
    """
    tags = tags_string.split(',')
    if not tags:
        raise Exception('README Tags parse failure!')
    return sorted([tag.strip() for tag in tags])


def get_readme_parts(content: str) -> (List[str], List[str]):
    """
    Split the README content into sections and section headers.

    :param content: The text in a README file.
    :return: A list of sections, and a list of section headers.
    """
    # A regular expression that matches exactly 2 pound marks, and capture
    # the trailing string.
    pattern = re.compile(r'^#{2}(?!#)\s(.*)', re.MULTILINE)
    # Use regex to split the README by section headers, so that they are
    # separated into paragraphs.
    readme_parts = re.split(pattern, content)
    # Find the section headers.
    readme_headers = re.findall(pattern, content)
    return readme_parts, readme_headers


def get_folder_name_from_path(path: str, index: int = -1) -> str:
    """
    Get the folder name from a full path.

    :param path: A string of a full/absolute path to a folder.
    :param index: The index of path parts. Default to -1 to get the most
    trailing folder in the path; set to certain index to get other parts.
    :return: The folder name.
    """
    return os.path.normpath(path).split(os.path.sep)[index]


def check_apis(apis_string: str) -> Set[str]:
    """
    Check the format for `Relevant API` section.

    :param apis_string: A multiline string containing all APIs.
    :return: A set of APIs. Throws if format is wrong.
    """
    stripped = apis_string.strip()
    apis = list(stripped.splitlines())
    if not apis:
        raise Exception('Empty Relevant APIs.')
    s = set()
    stripped_apis = []
    for api in apis:
        # Bullet is checked by the markdown linter, no need to check here.
        a = api.lstrip('*- ').rstrip()
        s.add(a)
        stripped_apis.append(a)
        if '`' in a:
            raise Exception('API should not include backticks.')
    if '' in s:
        raise Exception('Empty line in APIs.')
    if len(apis) > len(s):
        raise Exception('Duplicate APIs.')
    if stripped_apis != sorted(stripped_apis, key=str.casefold):
        raise Exception('APIs are not sorted.')
    return s


def check_tags(tags_string: str) -> Set[str]:
    """
    Check the format for `Tags` section.

    :param tags_string: A string containing all tags, with comma as delimiter.
    :return: A set of tags. Throws if format is wrong.
    """
    tags = tags_string.split(',')
    if not tags:
        raise Exception('Empty tags.')
    s = set()
    stripped_tags = []
    for tag in tags:
        t = tag.strip()
        s.add(t)
        stripped_tags.append(t)
        if t.lower() != t and t.upper() != t and t.capitalize() != t \
                and t not in exception_proper_nouns:
            raise Exception(f'Wrong letter case for tag: "{t}".')
    if '' in s:
        raise Exception('Empty char in tags.')
    if ', '.join(stripped_tags) != tags_string.strip():
        raise Exception('Extra whitespaces in tags.')
    if len(tags) > len(s):
        raise Exception('Duplicate tags.')
    if stripped_tags != sorted(stripped_tags, key=str.casefold):
        raise Exception('Tags are not sorted.')
    return s


def check_sentence_case(string: str) -> None:
    """
    Check if a sentence follows 'sentence case'. A few examples below.

    Hello world! -> YES
    I'm a good guy. -> YES
    a man and a gun. -> NO
    An OpenStreetMap layer -> YES, as it's allowed to include proper nouns

    :param string: Input sentence, typically the title string.
    :return: None. Throws if is not sentence case.
    """
    # Check empty string.
    if not string:
        raise Exception('Empty title string.')
    # The whole sentence get excepted.
    if string in exception_proper_nouns:
        return
    # Split sentence into words.
    words = string.split()
    # First word should either be Title-cased or a proper noun (UPPERCASE).
    if words[0][0].upper() != words[0][0] \
            and words[0].upper() != words[0] \
            and words[0] not in exception_proper_nouns:
        raise Exception('Wrong letter case for the first word in title.')
    # If a word is neither lowercase nor UPPERCASE then it is not great.
    for word in words[1:]:
        word = word.strip('()')
        if word.lower() != word \
                and word.upper() != word \
                and word not in exception_proper_nouns:
            raise Exception(f'Wrong letter case for word: "{word}" in title.')


def check_is_subsequence(list_a: List[str], list_b: List[str]) -> int:
    """
    Check if list A is a subsequence of list B.
    E.g.
    list_a = ['a', 'b', 'c']
    list_b = ['a', 'h', 'b', 'g', 'd', 'c']
    -> returns 0, which means all elements in list_a is also in list_b

    :param list_a: A list of strings, presumably the section titles of a README.
    :param list_b: A list of strings, presumably all valid titles in order.
    :return: 0 if list_a is subsequence of list_b.
    """
    # Empty list is always a subsequence of other lists.
    if not list_a:
        return True
    pa = len(list_a)
    for pb in range(len(list_b), 0, -1):
        if pa == 0:
            return 0
        pa -= 1 if list_b[pb - 1] == list_a[pa - 1] else 0
    return pa
# endregion


# region Classes
class Metadata:

    def __init__(self, folder_path: str):
        """
        The standard format of metadata.json for iOS platform. Read more at:
        common-samples/wiki/README.metadata.json

        :param folder_path: The folder that contains sample source code.
        """
        # The 9 common properties that exist on all platforms.
        self.category = ''          # Populate from path.
        self.description = ''       # Populate from README.
        self.ignore = False         # Default to False.
        self.images = []            # Populate from paths.
        self.keywords = []          # Populate from README.
        self.redirect_from = []     # Default to empty list.
        self.relevant_apis = []     # Populate from README.
        self.snippets = []          # Populate from paths.
        self.title = ''             # Populate from README.

        # A list of ArcGIS Portal Item IDs.
        self.offline_data = []      # Default to empty list.

        self.folder_path = folder_path
        self.folder_name = get_folder_name_from_path(folder_path)
        self.readme_path = os.path.join(folder_path, 'README.md')
        self.json_path = os.path.join(folder_path, 'README.metadata.json')

    def get_source_code_paths(self) -> List[str]:
        """
        Traverse the directory and get all filenames for source code.

        :return: A list of swift source code filenames.
        """
        results = []
        for file in os.listdir(self.folder_path):
            if os.path.splitext(file)[1] in ['.swift']:
                results.append(file)
        if not results:
            raise Exception('Unable to get swift source code paths.')
        return sorted(results)

    def get_images_paths(self):
        """
        Traverse the directory and get all filenames for images.

        :return: A list of image filenames.
        """
        results = []
        for file in os.listdir(self.folder_path):
            # Only allow PNG and GIF images.
            if os.path.splitext(file)[1].lower() in ['.png', '.gif']:
                results.append(file)
        if not results:
            raise Exception('Unable to get images paths.')
        return sorted(results)

    def populate_from_readme(self) -> None:
        """
        Read and parse the sections from README, and fill in the 'title',
        'description', 'relevant_apis' and 'keywords' fields in the dictionary
        for output json.
        """
        try:
            readme_file = open(self.readme_path, 'r')
            # read the readme content into a string
            readme_content = readme_file.read()
        except Exception as err:
            print(f"Error reading README - {self.readme_path} - {err}.")
            raise err
        else:
            readme_file.close()

        readme_parts, _ = get_readme_parts(readme_content)
        try:
            api_section_index = readme_parts.index('Relevant API') + 1
            tags_section_index = readme_parts.index('Tags') + 1
            self.title, self.description = parse_head(readme_parts[0])
            if self.title != self.folder_name:
                raise Exception(f'Folder name incorrect: "{self.folder_name}"')
            self.relevant_apis = parse_apis(readme_parts[api_section_index])
            keywords = parse_tags(readme_parts[tags_section_index])
            # De-duplicate API names in README's Tags section.
            self.keywords = [w for w in keywords if w not in self.relevant_apis]

            # "It combines the Tags and the Relevant APIs in the README."
            # See common-samples/wiki/README.metadata.json#keywords
            self.keywords += self.relevant_apis
            # self.keywords.sort(key=str.casefold)
        except Exception as err:
            print(f'Error parsing README - {self.readme_path} - {err}.')
            raise err

    def populate_from_paths(self) -> None:
        """
        Populate source code and image filenames from a sample's folder.
        """
        try:
            self.images = self.get_images_paths()
            self.snippets = self.get_source_code_paths()
        except Exception as err:
            print(f"Error parsing paths - {self.folder_name} - {err}.")
            raise err

    def flush_to_json_string(self) -> str:
        """
        Write the metadata to a json string.
        """
        data = dict()

        data["category"] = self.category
        data["description"] = self.description
        data["ignore"] = self.ignore
        data["images"] = self.images
        data["keywords"] = self.keywords
        data["redirect_from"] = self.redirect_from
        data["relevant_apis"] = self.relevant_apis
        data["snippets"] = self.snippets
        data["title"] = self.title
        if self.offline_data:
            # Only write offline_data when it is not empty.
            data["offline_data"] = self.offline_data

        return json.dumps(data, indent=4, sort_keys=True)

    def check_category(self) -> None:
        """
        Check if
        1. metadata contains a category.
        2. category is valid.
        
        :return: None. Throws if exception occurs.
        """
        if not self.category:
            raise Exception(f'Error category - Missing category.')
        elif self.category not in categories:
            raise Exception(f'Error category - Invalid category - "{self.category}".')


class Readme:
    essential_headers = {
        'Use case',
        'How to use the sample',
        'How it works',
        'Relevant API',
        'Tags'
    }

    available_headers = [
        'Use case',
        'How to use the sample',
        'How it works',
        'Relevant API',
        'Offline data',
        'About the data',
        'Additional information',
        'Tags'
    ]

    def __init__(self, folder_path: str):
        """
        The standard format of README.md for iOS platform. Read more at:
        common-samples/wiki/README-Template

        :param folder_path:  The folder that contains sample source code.
        """
        self.title = None
        self.description = None
        self.readme_content = None
        self.readme_parts = None
        self.readme_headers = None

        self.folder_path = folder_path
        self.folder_name = get_folder_name_from_path(folder_path)
        self.readme_path = os.path.join(folder_path, 'README.md')

    def populate_from_readme(self) -> None:
        """
        Read and parse the sections from README.

        :return: None. Throws if exception occurs.
        """
        try:
            readme_file = open(self.readme_path, 'r')
            # read the readme content into a string
            content = readme_file.read()
            self.readme_content = content
            # Use regex to split the README by section headers, so that they are
            # separated into paragraphs and section headers.
            self.readme_parts, self.readme_headers = get_readme_parts(content)
        except Exception as err:
            raise Exception(f'Error loading file - {self.readme_path} - {err}.')
        else:
            readme_file.close()

    def check_format_heading(self) -> None:
        """
        Check if
        1. essential section headers present.
        2. all sections are valid.
        3. section headers are in correct order.

        :return: None. Throws if exception occurs.
        """
        header_set = set(self.readme_headers)
        possible_header_set = set(self.available_headers)
        # Check if all sections are valid.
        sets_diff = header_set - possible_header_set
        if sets_diff:
            raise Exception(
                f'Error header - Unexpected header or extra whitespace'
                f' - "{sets_diff}".')
        # Check if all essential section headers present.
        sets_diff = self.essential_headers - header_set
        if sets_diff:
            raise Exception(
                f'Error header - Missing essential header(s) - "{sets_diff}".')
        # Check if all sections are in correct order.
        i = check_is_subsequence(self.readme_headers, self.available_headers)
        if i != 0:
            raise Exception(
                f'Error header - Wrong order at - '
                f'"{self.readme_headers[i-1]}".')

    def check_format_title_section(self) -> None:
        """
        Check if
        1. the head has at least 3 parts (title, description and image URLs).
        2. the title string uses sentence case.

        :return: None. Throws if exception occurs.
        """
        try:
            title, _ = parse_head(self.readme_parts[0])
            check_sentence_case(title)
        except Exception as err:
            raise Exception(f'Error title - {err}')

    def check_format_apis(self) -> None:
        """
        Check if APIs
        1. do not have backticks.
        2. are sorted.
        3. do not have duplicate entries.

        :return: None. Throws if exception occurs.
        """
        try:
            api_section_index = self.readme_parts.index('Relevant API') + 1
            check_apis(self.readme_parts[api_section_index])
        except Exception as err:
            raise Exception(f'Error APIs - {err}')

    def check_format_tags(self) -> None:
        """
        Check if tags
        1. are in correct case.
        2. are sorted.
        3. do not have duplicate entries.

        :return: None. Throws if exception occurs.
        """
        try:
            tags_section_index = self.readme_parts.index('Tags') + 1
            check_tags(self.readme_parts[tags_section_index])
        except Exception as err:
            raise Exception(f'Error tags - {err}')

    def check_redundant_apis_in_tags(self) -> None:
        """
        Check if APIs and tags intersect.

        :return: None. Throws if exception occurs.
        """
        try:
            tags_section_index = self.readme_parts.index('Tags') + 1
            api_section_index = self.readme_parts.index('Relevant API') + 1
            api_set = check_apis(self.readme_parts[api_section_index])
            tag_set = check_tags(self.readme_parts[tags_section_index])
            if not api_set.isdisjoint(tag_set):
                raise Exception(f'Error tags - API should not be in tags')
        except Exception as err:
            raise Exception(f'Error checking extra tags due to previous error '
                            f'- {err}')
# endregion
