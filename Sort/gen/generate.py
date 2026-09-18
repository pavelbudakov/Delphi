import random
import string

def generate_random_string(length, allowed_chars=string.ascii_letters + string.digits):
    """Генерирует случайную строку заданной длины из набора символов."""
    if length == 0:
        return ""
    return ''.join(random.choice(allowed_chars) for _ in range(length))

def generate_file(num_strings, min_len=1, max_len=100):
    """
    Генерирует файл с num_strings строками случайной длины.
    Длина каждой строки выбирается случайно в диапазоне [min_len, max_len].
    """
    with open('output.txt', 'w') as f:
        for _ in range(num_strings):
            length = random.randint(min_len, max_len)
            f.write(generate_random_string(length) + '\n')

# Пример использования
generate_file(10000)
