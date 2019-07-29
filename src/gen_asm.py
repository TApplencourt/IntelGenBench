#!/bin/env python3
import sys

template = sys.argv[1]
n = int(sys.argv[2])

from jinja2 import Template
with open(template) as file_:
    template = Template(file_.read())
print (template.render(n=n))

