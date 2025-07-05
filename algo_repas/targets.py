import numpy as np

ACTIVITY_MULTIPLIERS = {
    "very low": 1.2,
    "low": 1.375,
    "moderate": 1.55,
    "high": 1.725,
    "very high": 1.9
}

OBJECTIF_CALORIES = {
    "maintain": 0,
    "weight loss": -250,
    "weight gain": 250
}


class Target:
    def __init__(self, tdee, lbm_kg):
        self.tdee = tdee

        self.protein_g = lbm_kg * 1.6
        self.protein_cal = self.protein_g * 4

        self.lipid_cal = 0.30 * tdee
        self.lipid_g = self.lipid_cal / 9

        self.glucides_cal = 0.45 * tdee
        self.glucides_g = self.glucides_cal / 4


class User:
    def __init__(self, name, gender, age, height, weight_in_kg, activity_level: str, objectif: str,
                 body_fat_percent=0.12):
        self.name = name
        self.gender = gender
        self.height = height
        self.age = age
        self.weight_in_kg = weight_in_kg
        self.weight_in_pounds = weight_in_kg * 2.20462262185
        self.lean_body_mass_in_kg = weight_in_kg - (weight_in_kg * body_fat_percent)
        self.lean_body_mass_in_pounds = self.lean_body_mass_in_kg * 2.20462262185

        self.activity_multiplier = ACTIVITY_MULTIPLIERS.get(activity_level, 1.55)
        self.objectif_calories = OBJECTIF_CALORIES.get(objectif, 0)

        # Formule de Mifflin - St Jeor
        if gender == "male":
            self.bmr = 10 * weight_in_kg + 6.25 * height - 5 * age + 5
        elif gender == "female":
            self.bmr = 10 * weight_in_kg + 6.25 * height - 5 * age - 161
        else:
            raise ValueError("Gender must be male or female")

        self.tdee = self.bmr * self.activity_multiplier + self.objectif_calories
        self.target = Target(self.tdee, self.lean_body_mass_in_kg)

    def get_target(self) -> np.ndarray:
        return np.array([
            self.tdee,
            self.target.protein_cal,
            self.target.lipid_g,
            self.target.glucides_g
        ])
