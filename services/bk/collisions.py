import math


# probability of generating k keys that are unique.
def prob(k, n):
    return math.exp(-0.5 * k * (k-1)/n)


def unique_p(p, k, n):
    return p * (n - (k - 1)) / n


# Find N given k and a target probability
def find_N(k, p):
    return (k * (k-1)) / (-2 * math.log(1-p, math.e))


def find_char_num(k, p):
    N = find_N(k, p)
    return math.ceil(math.log(N, 64))



# print(1-unique_p(1, 2, 100000))
# exit()

TARGET = 1/1_000_000_000

# C = 1_000_000_000
# C = 64 ** 11
# C = 10_000
C = 6_003
# C = 40

# # N = 1000000
# CHAR=2
# N = 64**CHAR
# # N = 1000
# probUnique = 1.0
# print(1 - unique_p(probUnique, 1, N))
# for k in range(1, C):
#     # probUnique = unique_p(probUnique, k, N)
#     probUnique = probUnique * (N - (k - 1)) / N
#     # print(k, 1 - probUnique, 1 - math.exp(-0.5 * k * (k - 1) / N))
#     # print(k, 1 - probUnique, 1 - prob(k, N))
#     N = 64 ** CHAR
#     if (1-prob(k, N)) >= TARGET:
#         # N *= 10
#         CHAR += 1
#     print("{: 5}".format(k), N, 1 - prob(k, N))
# print('N:', N)
# print('chars:', CHAR)
# # print(64 ** 11)
# print()


N = find_N(C, TARGET)
print('N:', N)
# print(math.log(N, 64))
print('chars:', math.log(N, 64))
print('chars:', math.ceil(math.log(N, 64)))
print('chars:', find_char_num(C, TARGET))
print(prob(10, 1_000_000_000))

