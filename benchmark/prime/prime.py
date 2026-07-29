def is_prime(n):
    if n < 2:
        return False

    i = 2

    while i * i <= n:
        if n % i == 0:
            return False

        i += 1

    return True


def main():
    count = 0

    n = 2

    while n <= 1000000:
        if is_prime(n):
            count += 1

        n += 1

    print(count)


if __name__ == "__main__":
    main()