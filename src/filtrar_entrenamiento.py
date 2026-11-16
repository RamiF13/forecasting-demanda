
import pandas as pd

def filtrar_entrenamiento(df, umbral_ceros=0.9, dias_iniciales=37):
    """Recibe el DF de mart, excluye las series con más del 90% de días en cero y los primeros 37 días del período, y devuelve el DataFrame filtrado."""
    ceros_por_serie = (df['sales'] == 0).groupby([df['store_number'], df['family']]).transform('mean')
    corte = df['date'].min() + pd.Timedelta(days=dias_iniciales)
    mascara = ((ceros_por_serie <= umbral_ceros) & (df['date'] >= corte))
    return df[mascara]