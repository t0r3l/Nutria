import polars as pl
from huggingface_hub import hf_hub_download
import re
from unicodedata import normalize


def download_data(force_download=False):
    # 1. Télécharger le Parquet
    print("Downloading data...")
    local_parquet = hf_hub_download(
        repo_id="openfoodfacts/product-database",
        repo_type="dataset",
        filename="food.parquet",
        local_dir="./data/",
        force_download=force_download,
    )
    print("Data downloaded.")
    useful_columns = [
        'additives_n',
        'additives_tags',
        'allergens_tags',
        'brands_tags',
        'brands',
        'categories',
        'categories_tags',
        'categories_properties',
        'ciqual_food_name_tags',
        'cities_tags',
        'code',
        'compared_to_category',
        'complete',
        'completeness',
        'data_quality_errors_tags',
        'data_quality_info_tags',
        'data_quality_warnings_tags',
        'ecoscore_data',
        'ecoscore_grade',
        'ecoscore_score',
        'ecoscore_tags',
        'emb_codes_tags',
        'emb_codes',
        'food_groups_tags',
        'generic_name',
        'ingredients_analysis_tags',
        'ingredients_from_palm_oil_n',
        'ingredients_n',
        'ingredients_original_tags',
        'ingredients_percent_analysis',
        'ingredients_tags',
        'ingredients_text',
        'ingredients_with_specified_percent_n',
        'ingredients_with_unspecified_percent_n',
        'ingredients_without_ciqual_codes_n',
        'ingredients_without_ciqual_codes',
        'ingredients',
        'known_ingredients_n',
        'labels_tags',
        'labels',
        'languages_tags',
        'last_updated_t',
        'manufacturing_places',
        'minerals_tags',
        'misc_tags',
        'new_additives_n',
        'no_nutrition_data',
        'nova_group',
        'nova_groups_tags',
        'nova_groups',
        'nucleotides_tags',
        'nutrient_levels_tags',
        'nutriments',
        'nutriscore_grade',
        'nutriscore_score',
        'nutrition_data_per',
        'origins_tags',
        'origins',
        'owner_fields',
        'owner',
        'packaging_tags',
        'packagings',
        'product_name',
        'product_quantity_unit',
        'product_quantity',
        'quantity',
        'rev',
        'serving_quantity',
        'serving_size',
        'vitamins_tags',
        'with_non_nutritive_sweeteners',
        'with_sweeteners',
    ]

    # 2. Créer le plan lazy
    cleaned_df = (
        pl.scan_parquet(local_parquet)
        .select(useful_columns + ["countries_tags", "obsolete"])
        # ne charger que la colonne nécessaire avant tout
        .filter((pl.col("countries_tags").list.contains("en:france") & pl.col("obsolete") == False))
        .drop("countries_tags", "obsolete")
        .explode("product_name").unnest("product_name").filter(pl.col("lang") == "fr").select(
            # tous les autres champs sauf product_name
            *[c for c in useful_columns if c not in {"product_name"}],
            # on reprend "text" en l'appelant product_name
            pl.col("text").alias("product_name")
        )
    )

    return cleaned_df


def get_nutriments(data):
    nutriments = data.explode("nutriments").unnest("nutriments")

    macro_nutrients = [
        "energy-kcal",  # Énergie (kcal)
        "proteins",  # Protéines (g)
        "fat",  # Matières grasses totales (g)
        "carbohydrates",  # Glucides totaux (g)
        "fiber",  # Fibres alimentaires (g)
    ]

    # Pas utilisé car trop peu représenté dans le dataset
    # micro_nutriments = [
    #     "energy-kcal",
    #     "histidine",
    #     "isoleucine",
    #     "leucine",
    #     "methionine",
    #     "cystine",
    #     "phenylalanine",
    #     "tyrosine",
    #     "threonine",
    #     "tryptophan",
    #     "valine",
    #     "lysine",
    #     "fat",
    #     "fiber",
    #     "starch",
    #     "sugars",
    #     "glucose",
    #     "fructose",
    #     "lactose",
    #     "maltose",
    #     "galactose",
    #     "salt",
    #     "cholesterol",
    # ]

    main_information = [
        "code",
        "product_name",
        'categories',
        'nova_group',
        'labels'
    ]

    products_names_with_macro_nutriments = (
        nutriments
        .group_by(main_information)
        .agg([
            pl.col("100g")
            .filter(pl.col("name") == nutr)
            .first()
            .alias(nutr)
            for nutr in macro_nutrients
        ])
        .drop_nulls(macro_nutrients)
    )

    return products_names_with_macro_nutriments

"""Supprime les caractères n'utilisant pas les caractères non latins"""
def remove_non_latin(text: str) -> str:
    if text is None:
        return ""
    return ''.join(re.findall(r'[a-zA-ZÀ-ÿ0-9\s\-.,;:!?()\[\]{}]', text))


def clean_categories(data: pl.LazyFrame) -> pl.LazyFrame:
    cleaned_df = data.with_columns(
        pl.col("categories").map_elements(remove_non_latin, return_dtype=pl.String).alias("categories")
    )

    cleaned_df = cleaned_df.with_columns(
        pl.col("labels")
        .fill_null("")
        .str.to_lowercase()
        .str.replace_all(" ?, ?", ",")
        .str.replace_all(" ", "-")

        .alias("labels"),

        pl.col("categories")
        .fill_null("")
        .str.to_lowercase()
        .str.replace_all(" ?, ?", ",")
        .str.replace_all(" ", "-")
        .alias("categories"),
    )

    # Supprimer les accents :
    cleaned_df = cleaned_df.with_columns(
        pl.col("categories").map_elements(lambda x: normalize("NFKD", x).encode("ascii", "ignore").decode(),
                                          return_dtype=pl.String).alias("categories"),
        pl.col("labels").map_elements(lambda x: normalize("NFKD", x).encode("ascii", "ignore").decode(),
                                      return_dtype=pl.String).alias("labels")
    )

    return cleaned_df

def add_tags(data: pl.LazyFrame) -> pl.LazyFrame:
    return data.with_columns(
        # Tags régimes alimentaires :
        pl.col("labels").str.contains("halal").alias("halal"),
        pl.col("labels").str.contains("vegan").alias("vegan"),
        pl.col("labels").str.contains("bio").alias("bio"),
        pl.col("labels").str.contains("vegetarian").alias("vegetarian"),
        pl.col("labels").str.contains("gluten-free|sans-gluten|gluten-free|no-gluten").alias("gluten_free"),
        pl.col("labels").str.contains("koscher|kascher|casher").alias("kascher"),
        pl.col("labels").str.contains("sans-huile-de-palme|no-palm-oil").alias("no_palm_oil"),

        # Tags catégories nourritures
        pl.col("categories").str.contains("viandes|meat").alias("meat"),
        pl.col("categories").str.contains("pates|pasta").alias("pasta"),
        pl.col("categories").str.contains("boissons,|drinks").alias("drinks"),
        pl.col("categories").str.contains("produits-laitiers|lait|dairy").alias("lait"),
        pl.col("categories").str.contains("produits-de-la-mer|poisson|fish").alias("fish"),
        pl.col("categories").str.contains("snacks|chips,").alias("snacks"),
        pl.col("categories").str.contains("desserts|cakes").alias("desserts"),
        pl.col("categories").str.contains("condiments|sauce|epices").alias("condiments"),
        pl.col("categories").str.contains("plats-prepares").alias("plats_prepares"),
        pl.col("categories").str.contains("cereales-en-grains|cereales-et-pommes-de-terrre|feculents|pates").alias("feculents"),
        pl.col("categories").str.contains("pain|bread").alias("breads"),
    )


if __name__ == "__main__":
    df = download_data(True)

    df = get_nutriments(df)
    df = clean_categories(df)
    df = add_tags(df)

    df = df.collect()

    print(f"Nombre de lignes : {len(df)}")
    df.write_csv("./data/products_names_with_macro_nutriments.csv")
