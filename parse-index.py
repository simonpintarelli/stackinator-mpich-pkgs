#!/bin/env python

"""
Read html index of nexus repository, retrieve versions, filename and url for cray-[mpich, gtl, pmi, pals].
"""

from bs4 import BeautifulSoup
import pandas as pd
import sys
import numpy as np
import re

html_content = sys.stdin.read()


def read_index(html_content):
    """Read index of nexus repository/directory."""
    soup = BeautifulSoup(html_content, "html.parser")

    # Find the table in the HTML
    table = soup.find("table")
    if table is None:
        print("no table")
        sys.stderr.write("No table found.")
        sys.exit(1)

    # Get all the rows in the table
    rows = table.find_all("tr")

    # Alternatively, to store data in a list of dictionaries for further use:
    data = []
    for row in rows[1:]:  # Skip header row
        cols = row.find_all("td")
        name = cols[0].a.text if cols[0].a else ""
        url = cols[0].a["href"] if cols[0].a else ""
        last_modified = cols[1].text.strip()
        size = cols[2].text.strip()
        description = cols[3].text.strip() if len(cols) > 3 else ""
        data.append(
            {
                "Name": name,
                "URL": url,
                "Last Modified": last_modified,
                "Size": size,
                "Description": description,
            }
        )
    return pd.DataFrame(data)


def find_cray_mpich_gnu(index_df: pd.DataFrame) -> dict:
    names = index_df["Name"]
    matches_indices = np.where(
        names.str.contains(
            r"cray-mpich-(?!.*(ucx))[0-9]+\.[0-9]+\.[0-9]+-gnu", regex=True
        )
    )[0]
    if len(matches_indices) == 1:
        cray_mpich_gnu = names.iloc[matches_indices[0]]
        pattern = r"cray-mpich-([0-9]+\.[0-9]+\.[0-9]+)"
        match = re.match(pattern, cray_mpich_gnu)
        if not match:
            raise Exception(f"Could not match {pattern} in {cray_mpich_gnu}")
        return (
            index_df.iloc[matches_indices]
            .assign(Version=match.group(1))
            .iloc[0]
            .to_dict()
        )
    raise Exception("Could not find cray-mpich-[version]-gnu-*")


def find_cray_mpich_nvhpc(index_df: pd.DataFrame) -> dict:
    names = index_df["Name"]
    matches_indices = np.where(
        names.str.contains(
            r"cray-mpich-(?!.*(ucx))[0-9]+\.[0-9]+\.[0-9]+-nvidia", regex=True
        )
    )[0]
    if len(matches_indices) == 1:
        cray_mpich_gnu = names.iloc[matches_indices[0]]
        pattern = r"cray-mpich-([0-9]+\.[0-9]+\.[0-9]+)"
        match = re.match(pattern, cray_mpich_gnu)
        if not match:
            raise Exception(f"Could not match {pattern} in {cray_mpich_gnu}")
        return (
            index_df.iloc[matches_indices]
            .assign(Version=match.group(1))
            .iloc[0]
            .to_dict()
        )
    raise Exception("Could not find cray-mpich-[version]-nvidia-*")


def find_cray_pals(index_df: pd.DataFrame) -> dict:
    names = index_df["Name"]
    matches_indices = np.where(
        names.str.contains(r"cray-pals-[0-9]+\.[0-9]+\.[0-9]+-", regex=True)
    )[0]
    if len(matches_indices) == 1:
        cray_pals = names.iloc[matches_indices[0]]
        pattern = r"cray-pals-([0-9]+\.[0-9]+\.[0-9]+)"
        match = re.match(pattern, cray_pals)
        if not match:
            raise Exception(f"Could not match {pattern} in {cray_pals}")
        return (
            index_df.iloc[matches_indices]
            .assign(Version=match.group(1))
            .iloc[0]
            .to_dict()
        )
    raise Exception("Could not find cray-pals-[version]-*")


def find_cray_pmi(index_df: pd.DataFrame) -> dict:
    """Find cray-pmi and cray-pmi-devel"""
    names = index_df["Name"]
    matches_indices = np.where(
        names.str.contains(r"cray-pmi(-devel|)-[0-9]+\.[0-9]+\.[0-9]+-", regex=True)
    )[0]
    if len(matches_indices) == 2:
        cray_pmi = names.iloc[matches_indices[0]]
        pattern = r"cray-pmi-([0-9]+\.[0-9]+\.[0-9]+)"
        match = re.match(pattern, cray_pmi)
        if not match:
            raise Exception(f"Could not match {pattern} in {cray_pmi}")
        return (
            index_df.iloc[matches_indices]
            .assign(Version=match.group(1))
            .to_dict(orient="records")
        )
    raise Exception("Could not find cray-pmi-[version]-*")


def find_cray_mpich_gtl(index_df: pd.DataFrame, mpich_ver) -> dict:
    """Find cray-pmi and cray-pmi-devel"""
    names = index_df["Name"]
    matches_indices = np.where(
        names.str.contains(f"cray-mpich-{mpich_ver}-gtl", regex=True)
    )[0]
    if len(matches_indices) == 1:
        cray_mpich_gtl = names.iloc[matches_indices[0]]
        pattern = r"cray-mpich-([0-9]+\.[0-9]+\.[0-9]+)-gtl"
        match = re.match(pattern, cray_mpich_gtl)
        if not match:
            raise Exception(f"Could not match {pattern} in {cray_mpich_gtl}")
        return (
            index_df.iloc[matches_indices]
            .assign(Version=match.group(1))
            .iloc[0]
            .to_dict()
        )
    raise Exception("Could not find cray-gtl-[version]-*")


if __name__ == "__main__":
    df = read_index(html_content)
    mpich_gnu = find_cray_mpich_gnu(df)
    mpich_nvhpc = find_cray_mpich_nvhpc(df)
    pals = find_cray_pals(df)
    pmi, pmi_devel = find_cray_pmi(df)
    mpich_gtl = find_cray_mpich_gtl(df, mpich_ver=mpich_gnu["Version"])

    # print table: Name, URL, Version
    lines = [
        (y["Name"], y["URL"], y["Version"])
        for y in [mpich_gnu, mpich_nvhpc, pmi, pmi_devel, mpich_gtl, pals]
    ]
    for line in lines:
        print(*line, end="\n")
