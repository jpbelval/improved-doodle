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

def cheby2(fe, wp, ws, gpass, gstop):
    N, Wn = signal.cheb2ord(wp, ws, gpass, gstop, fs=fe)
    b, a = signal.cheby2(N, gstop, Wn=Wn, btype='lowpass', fs=fe)
    return b, a, N

def filtreButter():
    fe = 40
    wp = 1
    ws = 2
    gpass = 0.9
    gstop = 40.0
    bb, ba, bN = butter(fe, wp, ws, gpass, gstop)
    print(bN)
    zplane(bb, ba)
    w, h = signal.freqz(bb, ba)
    plt.figure()
    plt.plot(w, 20*np.log10(abs(h)))
    plt.title('Butter')
    plt.xlabel('rad/ech')
    plt.ylabel('gain (dB)')
    plt.show()

def filtreCheby2():
    fe = 40
    wp = 1.9
    ws = 2
    gpass = 0.9
    gstop = 40.0
    bb, ba, bN = cheby2(fe, wp, ws, gpass, gstop)
    print(bN)
    zplane(bb, ba)
    w, h = signal.freqz(bb, ba)
    plt.figure()
    plt.plot(w, 20*np.log10(abs(h)))
    plt.title('Cheby2')
    plt.xlabel('rad/ech')
    plt.ylabel('gain (dB)')
    plt.show()
    




if __name__ == '__main__':
    filtreButter()
    filtreCheby2()