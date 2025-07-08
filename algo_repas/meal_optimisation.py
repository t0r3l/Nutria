import numpy as np
import polars as pl
from scipy.optimize import nnls, lsq_linear
from algo_repas.targets import User

# TODO:
#   - Permettre de forcer la présence d'un aliment dans le repas
#   - Répartition des repas au cours de la journée
#   - Ajouter portion limite pour les produits (Changement du solveur par lsq_linear)
#   - Ajouter de la diversité dans les repas créés


def create_optimal_meals(user: User, products: pl.DataFrame, solveur = "nnls"):
    """
    Permet de calculer un repas selon les cibles de l'utilisateur et les produits disponibles.
    """
    targets = user.get_target() *0.3

    nutr_cols = ["energy-kcal","proteins", "fat", "carbohydrates"]
    arr = products.select(nutr_cols).to_numpy() / 100.0
    M = arr.T

    print("M shape:", M.shape)
    print("targets shape:", targets.shape)
    print("N:", N)

    lwr_bound = np.zeros(M.shape[1])
    higher_bound = products["portion_maximale"].to_numpy()

    print("lwr:",lwr_bound.shape)
    print("highr:", higher_bound.shape)

    # Appel solveur
    if solveur == "nnls":
        # NNLS : Pas de portion max donc repas trop riche en 1 élément
        # ou parfois plusieurs ingrédients du meme type (2 huiles différentes)
        x, _ = nnls(M, targets)
    elif solveur == "lsq":
        #   Lsq_Linear : Utilise tous les aliments de la base, ne fait pas de choix sur les produits (moins d'10g de produit)
        x = lsq_linear(
            M,
            targets,
            bounds=(lwr_bound, higher_bound),
            method="bvls",
        ).x

    else :
        raise ValueError("Solveur inconnu")

    # 5. Formatage du plan en polars
    plan = pl.DataFrame({
        "product_name": products["product_name"].to_list(),
        "quantité_g": x
    }).filter(pl.col("quantité_g") > 1e-6).sort("quantité_g", descending=True)

    # 6. Calcul des apports obtenus pour vérifier
    obtained = M @ x
    check = pl.DataFrame({
        "nutriment": ["energy-kcal", "proteins", "fat", "carbohydrates"],
        "obtenu_g": obtained,
        "cible_g": targets
    })

    print("Plan optimisé :")
    print(plan)
    print("\nVérif. apports :")
    print(check)


if __name__ == "__main__":
    user = User(
        "Test",
        "male",
        26,
        178,
        68,
        "moderate",
        "weight loss",
    )

    products = pl.read_csv(
        "../data_prep/data/products_names_with_macro_nutriments.csv",
        schema_overrides={
            "code": pl.Utf8,
        }

    ).filter(
        pl.col("snacks") == False,
        pl.col("desserts") == False,
        pl.col("drinks") == False,
        pl.col("condiments") == False,
        pl.col("complements") == False
    )

    create_optimal_meals(user, products, "ortools")
