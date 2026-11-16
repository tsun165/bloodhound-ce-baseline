import random, statistics, sys, time
def work():
    random.seed(42)
    a = [random.random() for _ in range(2_000_000)]
    a.sort()
    d = {}
    for i in range(3_000_000):
        k = i % 1000
        d[k] = d.get(k, 0) + i
    return len(a) + len(d)
ts = []
for _ in range(5):
    t = time.perf_counter(); work(); ts.append(time.perf_counter() - t)
print(sys.version.split()[0], "median_s=%.3f" % statistics.median(ts), " ".join("%.3f" % x for x in ts))
