
import pandas as pd

def separar_corte(df, corte, horizonte=10):
    """Recibe el DataFrame y un corte, devuelve el entrenamiento y la validación."""
    fin_validacion = corte + pd.Timedelta(days=horizonte)
    entrenamiento = df[df['date'] < corte]
    validacion = df[(df['date'] >= corte) & (df['date'] < fin_validacion)]
    return entrenamiento, validacion