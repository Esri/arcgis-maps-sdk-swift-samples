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

from common import *
import argparse


class MetadataCreator(Metadata):
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
        # If the results are empty, still return.
        return sorted(results)

    def flush_to_json_file(self, path_to_json: str) -> None:
        """
        Write the metadata to a json file.

        :param path_to_json: The path to the json file.
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

        with open(path_to_json, 'w+') as json_file:
            json.dump(data, json_file, indent=4, sort_keys=True)
            json_file.write('\n')


def create_one_metadata(path: str):
    """
    A handy helper function to create a sample's metadata.
    It writes to a separate json to avoid overwriting files.

    The path may look like '/Shared/Samples/Display map'
    """
    creator = MetadataCreator(path)
    try:
        creator.populate_from_readme()
        creator.populate_from_paths()
    except Exception:
        print(f'Error populate failed for - {creator.folder_name}.')
        return
    creator.flush_to_json_file(os.path.join(path, 'new-README.metadata.json'))


def main():
    msg = 'Create metadata from README. Run it against the folder of a ' \
          'single sample. E.g. /Shared/Samples/Display map'
    parser = argparse.ArgumentParser(description=msg)
    parser.add_argument('-c', '--create', help='path to a single sample')
    args = parser.parse_args()

    if args.create:
        create_one_metadata(args.create)
    else:
        print('Invalid arguments, abort.')


if __name__ == '__main__':
    main()
