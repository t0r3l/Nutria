#!/usr/bin/env python3
# count_true_tags.py
# -*- coding: utf-8 -*-

import polars as pl
import sys

# Chemin fixe vers le CSV
CSV_PATH = "./data/products_names_with_macro_nutriments.csv"

# Schéma personnalisé pour forcer 'code' en chaîne de caractères (le cas échéant)
SCHEMA_OVERRIDES = {'code': pl.Utf8}


def compute_true_counts(df: pl.DataFrame) -> pl.DataFrame:
    """
    Compte le nombre de valeurs vraies pour chaque colonne booléenne.

    :param df: DataFrame Polars
    :return: DataFrame longue avec deux colonnes: 'tag' et 'count_true'
    """
    # Identifier les colonnes de type booléen
    bool_cols = [name for name, dtype in df.schema.items() if dtype == pl.Boolean]
    if not bool_cols:
        raise ValueError("Aucune colonne booléenne trouvée dans le CSV.")

    # Somme des True (True == 1) pour chaque tag
    exprs = [pl.col(c).sum().alias(c) for c in bool_cols]
    counts_df = df.select(exprs)

    # Transformer en DataFrame longue: tag / count_true
    long_df = counts_df.melt(
        id_vars=[],
        value_vars=bool_cols,
        variable_name="tag",
        value_name="count_true"
    )
    return long_df.sort("tag")


if __name__ == '__main__':
    # Lecture du CSV avec schéma personnalisé
    df = pl.read_csv(CSV_PATH, schema_overrides=SCHEMA_OVERRIDES)

    # Calcul des comptes de True par tag
    df_true_counts = compute_true_counts(df)

    # Transpose du résultat pour avoir les tags en colonnes
    transposed = df_true_counts.transpose(include_header=True, header_name="tag")

    # Affichage en CSV
    transposed.write_csv(sys.stdout)

    bucket_url = get_terraform_output("object_url")
    print("URL S3:", bucket_url)
