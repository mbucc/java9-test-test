package com.example.util;

/**
 * A class that is not exported that we want to unit test.
 */

public class Util {
  private Util() {
    throw new UnsupportedOperationException("static only");
  }

  // Multiple by 2.
  public static int x2(int x) {
    return x * 2;
  }
}
