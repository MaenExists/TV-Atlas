#!/usr/bin/env python3
from setuptools import setup, find_packages

setup(
    name="tv-atlas",
    version="1.0.0",
    description="Interactive 3D Earth globe television explorer for worldwide live broadcasts",
    py_modules=["main", "tv_backend"],
    packages=find_packages(),
    include_package_data=True,
    install_requires=[
        "PySide6>=6.5.0",
    ],
    entry_points={
        "console_scripts": [
            "tv-atlas=main:main",
        ],
    },
)
