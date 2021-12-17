#include <cmath>
#include <string>
#include <vector>
#include <sstream>
#include <cstdio>
#include <iostream>
#include <utility>
#include "src/main.hxx"

using namespace std;




template <class G, class T>
void printRow(const G& x, const PagerankResult<T>& a, const PagerankResult<T>& b, const char *tec) {
  auto e = l1Norm(b.ranks, a.ranks);
  print(x); printf(" [%09.3f ms; %03d iters.] [%.4e err.] %s\n", b.time, b.iterations, e, tec);
}

void runPagerankBatch(const string& data, int repeat, int skip, int batch) {
  using T = float;
  using G = DiGraph<>;
  enum NormFunction { L0=0, L1=1, L2=2, Li=3 };
  vector<T> r0, s0, r1, s1;
  vector<T> *init = nullptr;
  PagerankOptions<T> o = {repeat, Li, true};

  DiGraph<> xo;
  stringstream s(data);
  while (true) {
    // Skip some edges (to speed up execution)
    if (skip>0 && !readSnapTemporal(xo, s, skip)) break;
    auto x  = selfLoop(xo, [&](int u) { return isDeadEnd(xo, u); });
    auto xt = transposeWithDegree(x);
    auto ksOld = vertices(x);
    auto a0 = pagerankNvgraph(x, xt, init, o);
    auto r0 = a0.ranks;

    // Read edges for this batch.
    auto yo = copy(xo);
    if (!readSnapTemporal(yo, s, batch)) break;
    auto y  = selfLoop(yo, [&](int u) { return isDeadEnd(yo, u); });
    auto yt = transposeWithDegree(y);
    auto ks = vertices(y);
    vector<T> s0(y.span());
    int X = ksOld.size();
    int Y = ks.size();

    // INSERTIONS:
    // Adjust ranks for insertions.
    adjustRanks(s0, r0, ksOld, ks, 0.0f, float(X)/(Y+1), 1.0f/(Y+1));

    // Find nvGraph-based pagerank.
    auto b0 = pagerankNvgraph(y, yt, init, o);
    printRow(y, b0, b0, "I:pagerankNvgraph (static)");
    auto c0 = pagerankNvgraph(y, yt, &s0, o);
    printRow(y, b0, c0, "I:pagerankNvgraph (incremental)");

    // Find sequential Monolithic pagerank.
    auto b1 = pagerankMonolithicSeq(y, yt, init, o);
    printRow(y, b0, b1, "I:pagerankMonolithicSeq (static)");
    auto c1 = pagerankMonolithicSeq(y, yt, &s0, o);
    printRow(y, b0, c1, "I:pagerankMonolithicSeq (incremental)");
    auto d1 = pagerankMonolithicSeqDynamic(x, xt, y, yt, &s0, o);
    printRow(y, b0, d1, "I:pagerankMonolithicSeq (dynamic)");

    // Find OpenMP-based Monolithic pagerank.
    auto b2 = pagerankMonolithicOmp(y, yt, init, o);
    printRow(y, b0, b2, "I:pagerankMonolithicOmp (static)");
    auto c2 = pagerankMonolithicOmp(y, yt, &s0, o);
    printRow(y, b0, c2, "I:pagerankMonolithicOmp (incremental)");
    auto d2 = pagerankMonolithicOmpDynamic(x, xt, y, yt, &s0, o);
    printRow(y, b0, d2, "I:pagerankMonolithicOmp (dynamic)");

    // Find CUDA-based Monolithic pagerank.
    auto b3 = pagerankMonolithicCuda(y, yt, init, o);
    printRow(y, b0, b3, "I:pagerankMonolithicCuda (static)");
    auto c3 = pagerankMonolithicCuda(y, yt, &s0, o);
    printRow(y, b0, c3, "I:pagerankMonolithicCuda (incremental)");
    auto d3 = pagerankMonolithicCudaDynamic(x, xt, y, yt, &s0, o);
    printRow(y, b0, d3, "I:pagerankMonolithicCuda (dynamic)");

    // Find sequential Componentwise pagerank.
    auto cs = components(y, yt);
    auto b  = blockgraph(y, cs);
    sortComponents(cs, b);
    PagerankData<G> D {move(cs), move(b)};
    auto b4 = pagerankComponentwiseSeq(y, yt, init, o, D);
    printRow(y, b0, b4, "I:pagerankComponentwiseSeq (static)");
    auto c4 = pagerankComponentwiseSeq(y, yt, &s0, o, D);
    printRow(y, b0, c4, "I:pagerankComponentwiseSeq (incremental)");
    auto d4 = pagerankComponentwiseSeqDynamic(x, xt, y, yt, &s0, o, D);
    printRow(y, b0, d4, "I:pagerankComponentwiseSeq (dynamic)");

    // Find OpenMP-based Componentwise pagerank.
    auto b5 = pagerankComponentwiseOmp(y, yt, init, o, D);
    printRow(y, b0, b5, "I:pagerankComponentwiseOmp (static)");
    auto c5 = pagerankComponentwiseOmp(y, yt, &s0, o, D);
    printRow(y, b0, c5, "I:pagerankComponentwiseOmp (incremental)");
    auto d5 = pagerankComponentwiseOmpDynamic(x, xt, y, yt, &s0, o, D);
    printRow(y, b0, d5, "I:pagerankComponentwiseOmp (dynamic)");

    // Find CUDA-based Componentwise pagerank.
    auto b6 = pagerankComponentwiseCuda(y, yt, init, o, D);
    printRow(y, b0, b6, "I:pagerankComponentwiseCuda (static)");
    auto c6 = pagerankComponentwiseCuda(y, yt, &s0, o, D);
    printRow(y, b0, c6, "I:pagerankComponentwiseCuda (incremental)");
    auto d6 = pagerankComponentwiseCudaDynamic(x, xt, y, yt, &s0, o, D);
    printRow(y, b0, d6, "I:pagerankComponentwiseCuda (dynamic)");

    // DELETIONS:
    // Adjust ranks for deletions.
    auto s1 = b0.ranks;
    vector<T> r1(x.span());
    adjustRanks(r1, s1, ks, ksOld, 0.0f, float(Y)/(X+1), 1.0f/(X+1));

    // Find nvGraph-based pagerank.
    auto e0 = pagerankNvgraph(x, xt, init, o);
    printRow(y, e0, e0, "D:pagerankNvgraph (static)");
    auto f0 = pagerankNvgraph(x, xt, &r1, o);
    printRow(y, e0, f0, "D:pagerankNvgraph (incremental)");

    // Find sequential Monolithic pagerank.
    auto e1 = pagerankMonolithicSeq(x, xt, init, o);
    printRow(y, e0, e1, "D:pagerankMonolithicSeq (static)");
    auto f1 = pagerankMonolithicSeq(x, xt, &r1, o);
    printRow(y, e0, f1, "D:pagerankMonolithicSeq (incremental)");
    auto g1 = pagerankMonolithicSeqDynamic(y, yt, x, xt, &r1, o);
    printRow(y, e0, g1, "D:pagerankMonolithicSeq (dynamic)");

    // Find OpenMP-based Monolithic pagerank.
    auto e2 = pagerankMonolithicOmp(x, xt, init, o);
    printRow(y, e0, e2, "D:pagerankMonolithicOmp (static)");
    auto f2 = pagerankMonolithicOmp(x, xt, &r1, o);
    printRow(y, e0, f2, "D:pagerankMonolithicOmp (incremental)");
    auto g2 = pagerankMonolithicOmpDynamic(y, yt, x, xt, &r1, o);
    printRow(y, e0, g2, "D:pagerankMonolithicOmp (dynamic)");

    // Find CUDA-based Monolithic pagerank.
    auto e3 = pagerankMonolithicCuda(x, xt, init, o);
    printRow(y, e0, e3, "D:pagerankMonolithicCuda (static)");
    auto f3 = pagerankMonolithicCuda(x, xt, &r1, o);
    printRow(y, e0, f3, "D:pagerankMonolithicCuda (incremental)");
    auto g3 = pagerankMonolithicCudaDynamic(y, yt, x, xt, &r1, o);
    printRow(y, e0, g3, "D:pagerankMonolithicCuda (dynamic)");

    // Find sequential Componentwise pagerank.
    auto ds = components(x, xt);
    auto c  = blockgraph(x, ds);
    sortComponents(ds, c);
    PagerankData<G> E {move(ds), move(c)};
    auto e4 = pagerankComponentwiseSeq(x, xt, init, o, E);
    printRow(y, e0, e4, "D:pagerankComponentwiseSeq (static)");
    auto f4 = pagerankComponentwiseSeq(x, xt, &r1, o, E);
    printRow(y, e0, f4, "D:pagerankComponentwiseSeq (incremental)");
    auto g4 = pagerankComponentwiseSeqDynamic(y, yt, x, xt, &r1, o, E);
    printRow(y, e0, g4, "D:pagerankComponentwiseSeq (dynamic)");

    // Find OpenMP-based Componentwise pagerank.
    auto e5 = pagerankComponentwiseOmp(x, xt, init, o, E);
    printRow(y, e0, e5, "D:pagerankComponentwiseOmp (static)");
    auto f5 = pagerankComponentwiseOmp(x, xt, &r1, o, E);
    printRow(y, e0, f5, "D:pagerankComponentwiseOmp (incremental)");
    auto g5 = pagerankComponentwiseOmpDynamic(y, yt, x, xt, &r1, o, E);
    printRow(y, e0, g5, "D:pagerankComponentwiseOmp (dynamic)");

    // Find CUDA-based Componentwise pagerank.
    auto e6 = pagerankComponentwiseCuda(x, xt, init, o, E);
    printRow(y, e0, e6, "D:pagerankComponentwiseCuda (static)");
    auto f6 = pagerankComponentwiseCuda(x, xt, &r1, o, E);
    printRow(y, e0, f6, "D:pagerankComponentwiseCuda (incremental)");
    auto g6 = pagerankComponentwiseCudaDynamic(y, yt, x, xt, &r1, o, E);
    printRow(y, e0, g6, "D:pagerankComponentwiseCuda (dynamic)");

    // New graph is now old.
    xo = move(yo);
  }
}


void runPagerank(const string& data, int repeat) {
  int M = countLines(data), steps = 10;
  printf("Temporal edges: %d\n", M);
  for (int batch=10, i=0; batch<M; batch*=i&1? 2:5, i++) {
    int skip = max(M/steps - batch, 0);
    printf("\n# Batch size %.0e\n", (double) batch);
    runPagerankBatch(data, repeat, skip, batch);
  }
}


int main(int argc, char **argv) {
  char *file = argv[1];
  int repeat = argc>2? stoi(argv[2]) : 5;
  printf("Using graph %s ...\n", file);
  string d = readFile(file);
  runPagerank(d, repeat);
    printf("\n");
  return 0;
}
