import matplotlib.pyplot as plt
import numpy as np
from scipy import signal
from zplane import zplane

def butter(fe, wp, ws, gpass, gstop):
    N, Wn = signal.buttord(wp, ws, gpass, gstop, fs=fe)
    b, a = signal.butter(N, Wn, 'lowpass', fs=fe)
    return b, a, N

def cheby1(fe, wp, ws, gpass, gstop):
    N, Wn = signal.cheb1ord(wp, ws, gpass, gstop, fs=fe)
    b, a = signal.cheby1(N, gpass, Wn=Wn, btype='lowpass', fs=fe)
    return b, a, N


def filtre():
    fe = 1600
    wp = 500.0
    ws = 750.0
    gpass = 0.2
    gstop = 60.0
    bb, ba, bN = butter(fe, wp, ws, gpass, gstop)
    cb, ca, cN = cheby1(fe, wp, ws, gpass, gstop)



if __name__ == '__main__':
    filtre()